import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/device_connectivity_provider.dart';
import '../../../coldigom/data/providers/coldigom_dio_provider.dart';
import '../../domain/entities/gesture_dictionary.dart';
import '../../domain/entities/gesture_document.dart';
import '../../domain/usecases/parse_gesture_dictionary.dart';
import '../../domain/usecases/parse_gesture_document.dart';
import '../../domain/utils/flatten_gesture_cards.dart';
import '../constants/gesture_dictionary_config.dart';
import '../datasources/gesture_content_datasource.dart';
import '../datasources/gesture_content_local_datasource.dart';
import '../datasources/gesture_dictionary_datasource.dart';
import '../datasources/gesture_dictionary_local_datasource.dart';
import '../datasources/gesture_figure_store.dart';
import '../repositories/gesture_figure_repository.dart';

final gestureContentDatasourceProvider = Provider<GestureContentDatasource>((ref) {
  return GestureContentDatasource(
    ref.watch(coldigomDioProvider),
    apiBase: AppConfig.apiBaseUrl,
  );
});

/// Cache Isar do documento; `null` de Isar = modo degradado.
final gestureContentLocalDatasourceProvider =
    Provider<GestureContentLocalDatasource>((ref) {
      return GestureContentLocalDatasource(ref.watch(optionalIsarProvider));
    });

final gestureDictionaryDatasourceProvider =
    Provider<GestureDictionaryDatasource>((ref) {
      return GestureDictionaryDatasource(
        ref.watch(coldigomDioProvider),
        baseUrl: GestureDictionaryConfig.baseUrl,
      );
    });

final gestureDictionaryLocalDatasourceProvider =
    Provider<GestureDictionaryLocalDatasource>((ref) {
      return GestureDictionaryLocalDatasource(ref.watch(optionalIsarProvider));
    });

final gestureFigureStoreProvider = Provider<GestureFigureStorePort>(
  (ref) => createGestureFigureStore(),
);

final gestureFigureRepositoryProvider = Provider<GestureFigureRepository>((ref) {
  return GestureFigureRepository(
    ref.watch(gestureFigureStoreProvider),
    ref.watch(coldigomDioProvider),
    apiBase: AppConfig.apiBaseUrl,
  );
});

/// Documento de um `r2Key`: `null` só quando o arquivo não existe.
///
/// Cópia do contrato do `chordSongProvider`: `autoDispose` + `keepAlive()` só
/// no sucesso (um `AsyncError` de rede não fica colado no louvor), cache-first
/// com revalidação em background quando stale e online, 404 grava marcador
/// negativo, `retry: null` desliga o backoff do Riverpod (quem abriu quer ver
/// "tentar de novo" agora). JSON inválido no cache ou na rede é conclusivo e
/// vira `AsyncError`.
final gestureDocumentProvider = FutureProvider.autoDispose
    .family<GestureDocument?, String>(retry: (_, _) => null, (ref, r2Key) async {
      final key = r2Key.trim();
      if (key.isEmpty) return null;

      final local = ref.watch(gestureContentLocalDatasourceProvider);
      final cached = local.read(key);
      if (cached != null) {
        if (cached.content.isEmpty) {
          ref.keepAlive();
          return null;
        }
        final doc = parseGestureDocument(cached.content);
        ref.keepAlive();
        if (cached.isStaleAt(DateTime.now())) {
          unawaited(_revalidateDocument(ref, key, cached.content, local));
        }
        return doc;
      }

      final remote = ref.watch(gestureContentDatasourceProvider);
      final content = await remote.fetchContent(key);
      if (content == null) {
        ref.keepAlive();
        local.write(key, '');
        return null;
      }
      final doc = parseGestureDocument(content);
      ref.keepAlive();
      local.write(key, content);
      return doc;
    });

Future<void> _revalidateDocument(
  Ref ref,
  String key,
  String cached,
  GestureContentLocalDatasource local,
) async {
  try {
    if (!await ref.read(deviceConnectivityProvider).hasConnection()) return;
    final fresh = await ref.read(gestureContentDatasourceProvider).fetchContent(key);
    if (fresh == null || fresh == cached) return;
    local.write(key, fresh);
    ref.invalidateSelf();
  } on Object catch (error) {
    debugPrint('[gestos] revalidação de $key falhou: $error');
  }
}

/// Dicionário global: `null` quando não há cache nem rede (a tela renderiza
/// com placeholders — não é erro).
///
/// Um objeto por sessão (`keepAlive` natural do `FutureProvider`). Cache-first;
/// stale + online → `If-None-Match`; 304 só renova `fetchedAt`.
final gestureDictionaryProvider = FutureProvider<GestureDictionary?>((ref) async {
  final local = ref.watch(gestureDictionaryLocalDatasourceProvider);
  final cached = local.read();
  if (cached != null) {
    final dict = _parseDictionaryOrNull(cached.content);
    if (dict != null) {
      if (cached.isStaleAt(DateTime.now())) {
        unawaited(_revalidateDictionary(ref, cached.etag, local));
      }
      return dict;
    }
  }

  final remote = ref.watch(gestureDictionaryDatasourceProvider);
  try {
    switch (await remote.fetch()) {
      case GestureDictionaryFresh(:final body, :final etag):
        final dict = _parseDictionaryOrNull(body);
        if (dict != null) local.write(content: body, etag: etag);
        return dict;
      case GestureDictionaryNotModified():
        // Sem cache local não há o que "não modificar"; trata como ausente.
        return null;
      case GestureDictionaryNotFound():
        return null;
    }
  } on GestureFetchFailedException catch (error) {
    debugPrint('[gestos] dicionário indisponível: $error');
    return null;
  }
});

GestureDictionary? _parseDictionaryOrNull(String body) {
  try {
    return parseGestureDictionary(body);
  } on GestureDictionaryParseException catch (error) {
    debugPrint('[gestos] dicionário ilegível: $error');
    return null;
  }
}

Future<void> _revalidateDictionary(
  Ref ref,
  String? etag,
  GestureDictionaryLocalDatasource local,
) async {
  try {
    if (!await ref.read(deviceConnectivityProvider).hasConnection()) return;
    switch (await ref.read(gestureDictionaryDatasourceProvider).fetch(etag: etag)) {
      case GestureDictionaryFresh(:final body, :final etag):
        if (_parseDictionaryOrNull(body) == null) return;
        local.write(content: body, etag: etag);
        ref.invalidateSelf();
      case GestureDictionaryNotModified():
        local.touch();
      case GestureDictionaryNotFound():
        break;
    }
  } on Object catch (error) {
    debugPrint('[gestos] revalidação do dicionário falhou: $error');
  }
}

/// Bytes de uma figura por `r2Key`; `null` se não deu. Fica viva na sessão:
/// a mesma figura aparece várias vezes no documento e no foco.
final gestureFigureProvider = FutureProvider.family<Uint8List?, String>((ref, r2Key) {
  return ref.watch(gestureFigureRepositoryProvider).get(r2Key);
});

/// Aquece o store com as figuras (PNG e GIF) dos ids de [document]
/// resolvidos por [dictionary]. Best-effort, dispara e esquece.
///
/// Recebe o repositório (não um `Ref`) para servir tanto a providers quanto
/// a widgets (`WidgetRef` não é `Ref`).
void prefetchGestureFigures(
  GestureFigureRepository repository,
  GestureDocument document,
  GestureDictionary dictionary,
) {
  final keys = <String>{};
  for (final flat in flattenGestureCards(document)) {
    final entry = dictionary.resolve(flat.card.gestureId);
    if (entry == null) continue;
    keys.add(entry.image);
    final gif = entry.gif;
    if (gif != null) keys.add(gif);
  }
  if (keys.isEmpty) return;
  unawaited(repository.prefetch(keys));
}
