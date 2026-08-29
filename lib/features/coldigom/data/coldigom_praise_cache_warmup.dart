import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/entities/louvor.dart';
import '../../catalog/domain/entities/louvor_data_source.dart';
import '../domain/utils/coldigom_praise_id.dart';
import 'adapters/coldigom_louvor_adapter.dart';
import 'providers/coldigom_providers.dart';

/// Preenche caches Coldigom (PDF + áudio) para os [praiseIds] do reload.
Future<void> warmupColdigomPraiseIds(
  Ref ref,
  Iterable<String> praiseIds,
) async {
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
      final detail = await datasource.fetchDetail(praiseId);
      ref
          .read(coldigomLouvoresCacheProvider.notifier)
          .mergeLouvores(ColdigomLouvorAdapter.toLouvores(detail));
      ref
          .read(coldigomAudioTracksCacheProvider.notifier)
          .mergeTracks(ColdigomLouvorAdapter.toAudioTracks(detail));
      ref
          .read(coldigomPraiseMetaCacheProvider.notifier)
          .put(praiseId, ColdigomLouvorAdapter.toMetadata(detail));
    } on Object {
      continue;
    }
  }
}

/// Busca sob demanda os materiais do praise ao abrir o leitor, se o cache
/// tiver só o PDF escolhido — habilita "Trocar material" na toolbar.
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

        final detail = await ref
            .read(coldigomRemoteDatasourceProvider)
            .fetchDetail(praiseId);
        ref
            .read(coldigomLouvoresCacheProvider.notifier)
            .mergeLouvores(ColdigomLouvorAdapter.toLouvores(detail));
        ref
            .read(coldigomAudioTracksCacheProvider.notifier)
            .mergeTracks(ColdigomLouvorAdapter.toAudioTracks(detail));
        ref
            .read(coldigomPraiseMetaCacheProvider.notifier)
            .put(praiseId, ColdigomLouvorAdapter.toMetadata(detail));
      };
    });
