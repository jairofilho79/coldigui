import '../../../../core/utils/material_id_kind.dart';
import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../catalog/domain/entities/catalog_material.dart';
import '../../../catalog/domain/entities/catalog_query.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/entities/youtube_material.dart';
import '../../../catalog/domain/ports/catalog_source.dart';
import '../../../catalog/domain/ports/search_cancellation.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../../domain/entities/coldigom_praise_metadata.dart';
import '../../domain/repositories/coldigom_search_repository.dart';
import '../../domain/utils/coldigom_praise_id.dart';

/// [CatalogSource] do acervo Coldigom sobre os caches em memória por tipo.
///
/// O `groupId` Coldigom é o praise id, que também está no path de todo id do
/// praise (`assets/praises/{praiseId}/…`) — é por ele que [groupForMaterial]
/// acha o grupo sem consultar a rede.
///
/// É a fonte **remota**: [searchLocal] é sempre vazio (não há índice do acervo
/// Coldigom no cliente) e [search] vai ao [searchRepository].
class ColdigomCatalogSource implements CatalogSource {
  const ColdigomCatalogSource({
    this.louvores = const {},
    this.audioTracks = const {},
    this.chords = const {},
    this.gestures = const {},
    this.praiseMeta = const {},
    this.youtube = const {},
    this.searchRepository,
  });

  /// PDFs Coldigom em cache, por `pdfId`.
  final Map<String, Louvor> louvores;

  /// Faixas Coldigom em cache, por `audioId`.
  final Map<String, AudioTrack> audioTracks;

  /// Cifras Coldigom em cache, por `chordId`.
  final Map<String, ChordMaterial> chords;

  /// Documentos de gestos Coldigom em cache, por `gestureId`.
  final Map<String, GestureMaterial> gestures;

  /// Metadados do praise em cache, por `groupId`.
  final Map<String, ColdigomPraiseMetadata> praiseMeta;

  /// Links de YouTube em cache, por `groupId`.
  final Map<String, List<YoutubeMaterial>> youtube;

  /// Porta de busca remota; `null` desliga [search] (fontes de teste).
  final ColdigomSearchRepository? searchRepository;

  /// PDFs Coldigom em cache pertencentes a [groupId].
  List<Louvor> louvoresOfGroup(String groupId) {
    if (groupId.isEmpty) return const [];
    return [
      for (final louvor in louvores.values)
        if (louvor.effectiveGroupId == groupId) louvor,
    ];
  }

  /// Versão síncrona de [groupById] — os caches já estão em memória.
  ///
  /// O grupo sai dos caches de PDF, cifra, áudio e YouTube. Devolve o grupo
  /// mesmo com um material só — o corte "sem alternativa" é de quem chama.
  /// Um praise que só tem link de YouTube continua `null`: YouTube não é
  /// endereçável e não sustenta um grupo sozinho.
  LouvorGroup? findGroupById(String groupId) {
    if (groupId.isEmpty) return null;
    final pdfs = louvoresOfGroup(groupId);
    final tracks = [
      for (final track in audioTracks.values)
        if (track.groupId == groupId) track,
    ];
    final groupChords = [
      for (final chord in chords.values)
        if (chord.groupId == groupId) chord,
    ];
    final groupGestures = [
      for (final gesture in gestures.values)
        if (gesture.groupId == groupId) gesture,
    ];
    if (pdfs.isEmpty &&
        tracks.isEmpty &&
        groupChords.isEmpty &&
        groupGestures.isEmpty) {
      return null;
    }

    final groups = LouvorGroup.fromLouvores(
      pdfs,
      audioTracks: tracks,
      chordMaterials: groupChords,
      gestureMaterials: groupGestures,
      youtubeMaterials: youtube[groupId] ?? const [],
      coldigomMetaByGroupId: praiseMeta,
    );
    return groups.isEmpty ? null : groups.first;
  }

  /// Versão síncrona de [materialById].
  CatalogMaterial? findMaterialById(String materialId) {
    switch (materialIdKindOf(materialId)) {
      case MaterialKind.pdf:
        final louvor = louvores[materialId];
        return louvor == null ? null : PdfMaterial(louvor);
      case MaterialKind.chord:
        final chord = chords[materialId];
        return chord == null ? null : ChordMaterialRef(chord);
      case MaterialKind.audio:
        final track = audioTracks[materialId];
        return track == null ? null : AudioMaterial(track);
      case MaterialKind.gesture:
        final gesture = gestures[materialId];
        return gesture == null ? null : GestureMaterialRef(gesture);
      // YouTube não vive no espaço de ids do app (o id vem do Worker).
      case MaterialKind.youtube:
      // Letra não tem cache neste source (o texto só vive no Isar, O6) —
      // quem resolve `lyrics:<praiseId>` é a camada offline, não este mapa
      // em memória.
      case MaterialKind.lyrics:
      case MaterialKind.unknown:
        return null;
    }
  }

  /// Versão síncrona de [groupForMaterial].
  LouvorGroup? findGroupForMaterial(String materialId) {
    final praiseId = coldigomPraiseIdFromPdfId(materialId);
    if (praiseId == null) return null;
    return findGroupById(praiseId);
  }

  @override
  Future<LouvorGroup?> groupById(String groupId) async =>
      findGroupById(groupId);

  @override
  Future<CatalogMaterial?> materialById(String materialId) async =>
      findMaterialById(materialId);

  @override
  Future<LouvorGroup?> groupForMaterial(String materialId) async =>
      findGroupForMaterial(materialId);

  /// Não há índice local do acervo Coldigom — a busca é sempre remota.
  @override
  List<LouvorGroup> searchLocal(CatalogQuery query) => const [];

  /// Uma página de `/api/plpcg/praises`, com cancelamento.
  ///
  /// Lança [SearchCancelledException] quando [cancellation] cancela antes da
  /// resposta chegar; o repositório também grava os materiais nos caches.
  @override
  Future<CatalogSearchPage> search(
    CatalogQuery query, {
    SearchCancellation? cancellation,
  }) async {
    final repository = searchRepository;
    if (repository == null || query.isEmpty) return CatalogSearchPage.empty;

    final result = await repository.search(
      query.text.trim(),
      page: query.page,
      cancellation: cancellation,
    );
    return CatalogSearchPage(
      groups: result.groups,
      page: result.page,
      hasNextPage: result.hasNextPage,
    );
  }
}
