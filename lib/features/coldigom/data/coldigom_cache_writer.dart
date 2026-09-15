import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio_player/domain/entities/audio_track.dart';
import '../../catalog/domain/entities/catalog_material.dart';
import '../../catalog/domain/entities/louvor.dart';
import '../../catalog/domain/entities/youtube_material.dart';
import '../../chords/domain/entities/chord_material.dart';
import '../../gestures/domain/entities/gesture_material.dart';
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
      gestureMaterials: result.gestureMaterials,
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
      gestureMaterials: result.gestureMaterials,
      youtubeMaterials: result.youtubeMaterials,
      metaByGroupId: result.praiseMetaByGroupId,
    );
  }

  /// Funde só cifras — o sheet e o desvio de `/cifra` já têm o objeto pronto.
  void mergeChords(Iterable<ChordMaterial> chords) {
    _ref.read(coldigomChordMaterialsCacheProvider.notifier).mergeChords(chords);
  }

  /// Funde só gestos — o sheet e o desvio de `/gestos` já têm o objeto pronto.
  void mergeGestures(Iterable<GestureMaterial> gestures) {
    _ref
        .read(coldigomGestureMaterialsCacheProvider.notifier)
        .mergeGestures(gestures);
  }

  /// Funde o detalhe completo de um praise (warmup e abertura do leitor).
  void mergePraiseDetail(String praiseId, PraiseDetailDto detail) {
    _merge(
      louvores: ColdigomLouvorAdapter.toLouvores(detail),
      audioTracks: ColdigomLouvorAdapter.toAudioTracks(detail),
      chordMaterials: ColdigomLouvorAdapter.toChordMaterials(detail),
      gestureMaterials: ColdigomLouvorAdapter.toGestureMaterials(detail),
      youtubeMaterials: ColdigomLouvorAdapter.toYoutubeMaterials(detail),
      metaByGroupId: {praiseId: ColdigomLouvorAdapter.toMetadata(detail)},
    );
  }

  /// Funde só letras — a hidratação e a adoção dos «novos» da pesquisa.
  void mergeLyrics(Iterable<LyricsMaterial> lyrics) {
    _ref.read(coldigomLyricsCacheProvider.notifier).mergeLyrics(lyrics);
  }

  /// Funde o catálogo inteiro hidratado do Isar (O4) — **uma** escrita por
  /// cache. 1690 `mergePraiseDetail` copiariam o mapa de 20 k entradas 1690
  /// vezes; aqui cada notifier copia uma vez.
  void mergeCatalog({
    required List<Louvor> louvores,
    required List<AudioTrack> audioTracks,
    required List<ChordMaterial> chordMaterials,
    required List<GestureMaterial> gestureMaterials,
    required List<YoutubeMaterial> youtubeMaterials,
    required List<LyricsMaterial> lyrics,
    required Map<String, ColdigomPraiseMetadata> metaByGroupId,
  }) {
    _merge(
      louvores: louvores,
      audioTracks: audioTracks,
      chordMaterials: chordMaterials,
      gestureMaterials: gestureMaterials,
      youtubeMaterials: youtubeMaterials,
      metaByGroupId: metaByGroupId,
    );
    mergeLyrics(lyrics);
  }

  void _merge({
    required List<Louvor> louvores,
    required List<AudioTrack> audioTracks,
    required List<ChordMaterial> chordMaterials,
    required List<GestureMaterial> gestureMaterials,
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
        .read(coldigomGestureMaterialsCacheProvider.notifier)
        .mergeGestures(gestureMaterials);
    _ref
        .read(coldigomYoutubeCacheProvider.notifier)
        .mergeYoutube(youtubeMaterials);
    _ref
        .read(coldigomPraiseMetaCacheProvider.notifier)
        .mergeMeta(metaByGroupId);
  }
}
