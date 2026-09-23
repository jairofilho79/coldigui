import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/entities/youtube_material.dart';
import '../../../catalog/domain/ports/search_cancellation.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../entities/coldigom_praise_metadata.dart';

/// Porta de busca coldigom.
abstract interface class ColdigomSearchRepository {
  /// Busca via `/api/plpcg/praises` → grupos para exibição na Home.
  ///
  /// Query vazia → listas vazias (comportamento Home). [cancellation] aborta
  /// a requisição HTTP em curso; nesse caso o future termina com
  /// [SearchCancelledException] em vez de um erro de rede.
  Future<ColdigomSearchResult> search(
    String query, {
    int page = 1,
    SearchCancellation? cancellation,
  });
}

/// Resultado da busca coldigom com louvores/áudios flat para cache.
class ColdigomSearchResult {
  const ColdigomSearchResult({
    required this.groups,
    required this.louvores,
    this.audioTracks = const [],
    this.youtubeMaterials = const [],
    this.chordMaterials = const [],
    this.gestureMaterials = const [],
    this.praiseMetaByGroupId = const {},
    this.page = 1,
    this.hasNextPage = false,
  });

  final List<LouvorGroup> groups;
  final List<Louvor> louvores;
  final List<AudioTrack> audioTracks;
  final List<YoutubeMaterial> youtubeMaterials;
  final List<ChordMaterial> chordMaterials;
  final List<GestureMaterial> gestureMaterials;
  final Map<String, ColdigomPraiseMetadata> praiseMetaByGroupId;
  final int page;
  final bool hasNextPage;
}
