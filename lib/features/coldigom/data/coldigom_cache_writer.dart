import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio_player/domain/entities/audio_track.dart';
import '../../catalog/domain/entities/louvor.dart';
import '../../catalog/domain/entities/youtube_material.dart';
import '../../chords/domain/entities/chord_material.dart';
import '../domain/entities/coldigom_praise_metadata.dart';
import '../domain/repositories/coldigom_search_repository.dart';
import 'adapters/coldigom_louvor_adapter.dart';
import 'models/praise_dto.dart';
import 'providers/coldigom_providers.dart';

/// Ponto único de escrita nos caches Coldigom (C.3).
///
/// Antes cada chamador da presentation fundia os resultados nos cinco
/// notifiers na mão — quatro arquivos repetindo a mesma sequência, cada um
/// esquecendo um cache diferente (o de YouTube nem existia). Aqui a regra é
/// uma só: quem recebe um resultado do repositório entrega o resultado
/// inteiro, e o data decide o que vai para onde.
class ColdigomCacheWriter {
  ColdigomCacheWriter(this._ref);

  final Ref _ref;

  /// Funde tudo o que veio de uma busca da Home.
  void mergeSearchResult(ColdigomSearchResult result) {
    _merge(
      louvores: result.louvores,
      audioTracks: result.audioTracks,
      chordMaterials: result.chordMaterials,
      youtubeMaterials: result.youtubeMaterials,
      metaByGroupId: result.praiseMetaByGroupId,
    );
  }

  /// Funde tudo o que veio de um browse da Biblioteca.
  void mergeBrowseResult(ColdigomBrowseResult result) {
    _merge(
      louvores: result.louvores,
      audioTracks: result.audioTracks,
      chordMaterials: result.chordMaterials,
      youtubeMaterials: result.youtubeMaterials,
      metaByGroupId: result.praiseMetaByGroupId,
    );
  }

  /// Funde só cifras — o sheet e o desvio de `/cifra` já têm o objeto pronto.
  void mergeChords(Iterable<ChordMaterial> chords) {
    _ref.read(coldigomChordMaterialsCacheProvider.notifier).mergeChords(chords);
  }

  /// Funde o detalhe completo de um praise (warmup e abertura do leitor).
  void mergePraiseDetail(String praiseId, PraiseDetailDto detail) {
    _merge(
      louvores: ColdigomLouvorAdapter.toLouvores(detail),
      audioTracks: ColdigomLouvorAdapter.toAudioTracks(detail),
      chordMaterials: ColdigomLouvorAdapter.toChordMaterials(detail),
      youtubeMaterials: ColdigomLouvorAdapter.toYoutubeMaterials(detail),
      metaByGroupId: {praiseId: ColdigomLouvorAdapter.toMetadata(detail)},
    );
  }

  void _merge({
    required List<Louvor> louvores,
    required List<AudioTrack> audioTracks,
    required List<ChordMaterial> chordMaterials,
    required List<YoutubeMaterial> youtubeMaterials,
    required Map<String, ColdigomPraiseMetadata> metaByGroupId,
  }) {
    // Cada notifier ignora entrada vazia, então não há cópia de mapa à toa.
    _ref.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores(louvores);
    _ref
        .read(coldigomAudioTracksCacheProvider.notifier)
        .mergeTracks(audioTracks);
    _ref
        .read(coldigomChordMaterialsCacheProvider.notifier)
        .mergeChords(chordMaterials);
    _ref
        .read(coldigomYoutubeCacheProvider.notifier)
        .mergeYoutube(youtubeMaterials);
    _ref
        .read(coldigomPraiseMetaCacheProvider.notifier)
        .mergeMeta(metaByGroupId);
  }
}
