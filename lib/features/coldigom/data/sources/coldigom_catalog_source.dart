import '../../../../core/utils/material_id_kind.dart';
import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../catalog/domain/entities/catalog_material.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/ports/catalog_source.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../domain/entities/coldigom_praise_metadata.dart';
import '../../domain/utils/coldigom_praise_id.dart';

/// [CatalogSource] do acervo Coldigom sobre os caches em memória por tipo.
///
/// O `groupId` Coldigom é o praise id, que também está no path de todo id do
/// praise (`assets/praises/{praiseId}/…`) — é por ele que [groupForMaterial]
/// acha o grupo sem consultar a rede.
class ColdigomCatalogSource implements CatalogSource {
  const ColdigomCatalogSource({
    this.louvores = const {},
    this.audioTracks = const {},
    this.chords = const {},
    this.praiseMeta = const {},
  });

  /// PDFs Coldigom em cache, por `pdfId`.
  final Map<String, Louvor> louvores;

  /// Faixas Coldigom em cache, por `audioId`.
  final Map<String, AudioTrack> audioTracks;

  /// Cifras Coldigom em cache, por `chordId`.
  final Map<String, ChordMaterial> chords;

  /// Metadados do praise em cache, por `groupId`.
  final Map<String, ColdigomPraiseMetadata> praiseMeta;

  /// PDFs Coldigom em cache pertencentes a [groupId].
  List<Louvor> louvoresOfGroup(String groupId) {
    if (groupId.isEmpty) return const [];
    return [
      for (final louvor in louvores.values)
        if (louvor.effectiveGroupId == groupId) louvor,
    ];
  }

  /// Versão síncrona de [groupById] — os caches já estão em memória.
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
    if (pdfs.isEmpty && tracks.isEmpty && groupChords.isEmpty) return null;

    final groups = LouvorGroup.fromLouvores(
      pdfs,
      audioTracks: tracks,
      chordMaterials: groupChords,
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
      // YouTube não vive no espaço de ids do app (o id vem do Worker) e gesto
      // abre pelo caminho de PDF do leitor — nenhum dos dois é endereçável.
      case MaterialKind.youtube:
      case MaterialKind.gesture:
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
}
