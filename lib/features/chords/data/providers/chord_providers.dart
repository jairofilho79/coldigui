import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/device_connectivity_provider.dart';
import '../../../coldigom/data/providers/coldigom_dio_provider.dart';
import '../../domain/entities/chordpro_song.dart';
import '../datasources/chord_content_datasource.dart';
import '../datasources/chord_content_local_datasource.dart';

/// Datasource de conteúdo de cifra.
final chordContentDatasourceProvider = Provider<ChordContentDatasource>((ref) {
  return ChordContentDatasource(
    ref.watch(coldigomDioProvider),
    apiBase: AppConfig.apiBaseUrl,
  );
});

/// Cache Isar do conteúdo de cifra; `null` de Isar = modo degradado.
final chordContentLocalDatasourceProvider =
    Provider<ChordContentLocalDatasource>((ref) {
      return ChordContentLocalDatasource(ref.watch(optionalIsarProvider));
    });

/// Música de um `r2Key`: `null` só quando a cifra não existe.
///
/// **`autoDispose` + `keepAlive` só no sucesso** é o par que resolve o bug: um
/// `FutureProvider.family` comum vive enquanto o `ProviderScope` viver, então
/// um `AsyncError` de uma piscada de rede ficaria colado no louvor pelo resto
/// da sessão (e o `keepAlive` seria um no-op, porque nada estava para ser
/// descartado). Sendo `autoDispose`, o elemento em erro morre quando o último
/// widget para de ouvir, e a próxima abertura do sheet tenta de novo sozinha.
/// No sucesso o `keepAlive` segura o resultado — arquivos minúsculos, reabrir a
/// mesma cifra é comum.
///
/// Cache-first: o conteúdo guardado no Isar responde na hora (a cifra abre
/// offline) e, passado [kChordCacheTtl], uma revalidação em background troca o
/// corpo se ele mudou. 404 grava **marcador negativo** (conteúdo vazio) — sem
/// ele, `autoDispose` faria um GET por abertura de sheet no caso mais comum, o
/// louvor sem cifra.
///
/// `retry` devolvendo `null` desliga o backoff automático do Riverpod 3 (até 10
/// tentativas, ~40 s preso em `AsyncLoading`): quem abriu o louvor precisa ver
/// "indisponível · tentar de novo" agora, e a nova tentativa é o toque do
/// usuário.
final chordSongProvider = FutureProvider.autoDispose
    .family<ChordProSong?, String>(retry: (_, _) => null, (ref, r2Key) async {
      final key = r2Key.trim();
      if (key.isEmpty) return null;

      final local = ref.watch(chordContentLocalDatasourceProvider);
      final cached = local.read(key);
      if (cached != null) {
        ref.keepAlive();
        if (cached.isStaleAt(DateTime.now())) {
          unawaited(_revalidate(ref, key, cached.content, local));
        }
        return parseChordSongOrNull(cached.content);
      }

      final remote = ref.watch(chordContentDatasourceProvider);
      final content = await remote.fetchContent(key);
      ref.keepAlive();
      // 404 também é resposta conclusiva: grava o marcador negativo.
      local.write(key, content ?? '');
      return content == null ? null : parseChordSongOrNull(content);
    });

/// Rebusca [key] quando há rede e troca o cache se o corpo mudou.
///
/// Best-effort: qualquer falha aqui só apaga a chance de atualizar — a cifra
/// já foi entregue do cache.
Future<void> _revalidate(
  Ref ref,
  String key,
  String cached,
  ChordContentLocalDatasource local,
) async {
  try {
    if (!await ref.read(deviceConnectivityProvider).hasConnection()) return;
    final fresh = await ref
        .read(chordContentDatasourceProvider)
        .fetchContent(key);
    if (fresh == null || fresh == cached) return;
    local.write(key, fresh);
    ref.invalidateSelf();
  } on Object catch (error) {
    debugPrint('[cifras] revalidação de $key falhou: $error');
  }
}
