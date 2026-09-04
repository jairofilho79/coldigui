import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/entities/louvor.dart';
import '../../catalog/domain/entities/louvor_data_source.dart';
import '../domain/utils/coldigom_praise_id.dart';
import 'adapters/coldigom_louvor_adapter.dart';
import 'providers/coldigom_providers.dart';

/// Tempo máximo padrão para o warmup Coldigom aguardar a rede (A3).
///
/// Best-effort: nunca deve travar quem chama — ver [warmupColdigomPraiseIds]
/// e [ensureColdigomPraiseMaterialsCachedProvider].
const Duration coldigomWarmupDefaultTimeout = Duration(seconds: 5);

/// Preenche caches Coldigom (PDF + áudio) para os [praiseIds] do reload.
///
/// [timeout] limita cada busca de detalhe — nunca propaga falha de rede
/// (timeout incluído) para o chamador; apenas registra e segue para o
/// próximo id.
Future<void> warmupColdigomPraiseIds(
  Ref ref,
  Iterable<String> praiseIds, {
  Duration timeout = coldigomWarmupDefaultTimeout,
}) async {
  final unique = {
    for (final id in praiseIds)
      if (id.isNotEmpty) id,
  };
  if (unique.isEmpty) return;

  final datasource = ref.read(coldigomRemoteDatasourceProvider);
  for (final praiseId in unique) {
    final hasPdf = ref
        .read(coldigomLouvoresCacheProvider)
        .values
        .any((l) => coldigomPraiseIdFromPdfId(l.pdfId) == praiseId);
    final hasAudio = ref
        .read(coldigomAudioTracksCacheProvider)
        .values
        .any((t) => t.groupId == praiseId);
    if (hasPdf && hasAudio) continue;

    try {
      final detail = await datasource.fetchDetail(praiseId).timeout(timeout);
      ref
          .read(coldigomLouvoresCacheProvider.notifier)
          .mergeLouvores(ColdigomLouvorAdapter.toLouvores(detail));
      ref
          .read(coldigomAudioTracksCacheProvider.notifier)
          .mergeTracks(ColdigomLouvorAdapter.toAudioTracks(detail));
      ref
          .read(coldigomChordMaterialsCacheProvider.notifier)
          .mergeChords(ColdigomLouvorAdapter.toChordMaterials(detail));
      ref
          .read(coldigomPraiseMetaCacheProvider.notifier)
          .put(praiseId, ColdigomLouvorAdapter.toMetadata(detail));
    } on Object catch (e) {
      debugPrint('[coldigom] warmup falhou para $praiseId: $e');
      continue;
    }
  }
}

/// Dispara o warmup do praise em background, sem atrasar nem impedir a
/// navegação (A3).
///
/// Recebe a função já lida do [ensureColdigomPraiseMaterialsCachedProvider]
/// porque os dois chamadores têm refs de tipos diferentes (`WidgetRef` ao abrir
/// da Home, `Ref` no provider do carousel). O timeout **não** é reaplicado
/// aqui: ele já está dentro do provider, e duplicá-lo só dobraria a espera.
void warmupColdigomInBackground(
  Future<void> Function(Louvor) ensureMaterialsCached,
  Louvor louvor,
) {
  unawaited(
    ensureMaterialsCached(louvor).catchError((Object e) {
      debugPrint('[coldigom] warmup falhou: $e');
    }),
  );
}

/// Busca sob demanda os materiais do praise ao abrir o leitor, se o cache
/// tiver só o PDF escolhido — habilita "Trocar material" na toolbar.
///
/// Best-effort: nunca lança para o chamador, mesmo com falha/timeout de
/// rede (A3) — apenas registra via [debugPrint] e retorna.
final ensureColdigomPraiseMaterialsCachedProvider =
    Provider<Future<void> Function(Louvor)>((ref) {
      return (Louvor louvor) async {
        if (louvor.source != LouvorDataSource.coldigom) return;

        final praiseId = coldigomPraiseIdFromPdfId(louvor.pdfId);
        if (praiseId == null) return;

        ref.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
          louvor,
        ]);

        final cache = ref.read(coldigomLouvoresCacheProvider);
        final siblingsInCache = cache.values
            .where((l) => coldigomPraiseIdFromPdfId(l.pdfId) == praiseId)
            .length;
        final audioSiblings = ref
            .read(coldigomAudioTracksCacheProvider)
            .values
            .where((t) => t.groupId == praiseId)
            .length;
        if (siblingsInCache > 1 || audioSiblings > 0) return;

        try {
          final detail = await ref
              .read(coldigomRemoteDatasourceProvider)
              .fetchDetail(praiseId)
              .timeout(coldigomWarmupDefaultTimeout);
          ref
              .read(coldigomLouvoresCacheProvider.notifier)
              .mergeLouvores(ColdigomLouvorAdapter.toLouvores(detail));
          ref
              .read(coldigomAudioTracksCacheProvider.notifier)
              .mergeTracks(ColdigomLouvorAdapter.toAudioTracks(detail));
          ref
              .read(coldigomChordMaterialsCacheProvider.notifier)
              .mergeChords(ColdigomLouvorAdapter.toChordMaterials(detail));
          ref
              .read(coldigomPraiseMetaCacheProvider.notifier)
              .put(praiseId, ColdigomLouvorAdapter.toMetadata(detail));
        } on Object catch (e) {
          debugPrint('[coldigom] warmup falhou para $praiseId: $e');
        }
      };
    });
