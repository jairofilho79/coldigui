import '../../../catalog/domain/entities/louvor.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../entities/audio_track.dart';

/// Categoria do material de áudio "principal" no acervo Coldigom.
///
/// As demais são variações (Playback, MIDI…) — ver [AudioTrack.categoria].
const kPrimaryAudioCategoria = 'Áudio';

/// Ponte áudio → partitura: material (PDF ou cifra) do louvor [groupId].
///
/// Ordem de preferência:
/// 1. o material desse louvor que **já está na lista ativa**
///    ([carouselPdfIds]) — respeita a escolha do usuário (PRODUCT §4: a lista
///    é de louvores, não de um tipo de arquivo);
/// 2. senão o primeiro PDF do grupo no catálogo ([catalog] e [byPdfId]);
/// 3. senão `null` (louvor sem material de leitura).
///
/// [byPdfId] é o cache Coldigom (`pdfId → Louvor`); [catalog] é o manifest
/// PLPCG; [chordsById] é o cache de cifras (`chordId` vive no mesmo espaço de
/// ids do `pdfId`).
String? findMaterialForGroup({
  required String groupId,
  required List<String> carouselPdfIds,
  required Map<String, Louvor> byPdfId,
  Map<String, ChordMaterial> chordsById = const {},
  List<Louvor> catalog = const [],
}) {
  final gid = groupId.trim();
  if (gid.isEmpty) return null;

  for (final pdfId in carouselPdfIds) {
    final materialGroupId = groupIdForMaterialId(
      materialId: pdfId,
      byPdfId: byPdfId,
      chordsById: chordsById,
      catalog: catalog,
    );
    if (materialGroupId == gid) return pdfId;
  }

  for (final louvor in catalog) {
    if (louvor.effectiveGroupId == gid) return louvor.pdfId;
  }
  for (final louvor in byPdfId.values) {
    if (louvor.effectiveGroupId == gid) return louvor.pdfId;
  }
  return null;
}

/// `groupId` do louvor a que [materialId] (PDF ou cifra) pertence.
///
/// Retorna `null` quando o id não está em nenhum dos caches/catálogo.
String? groupIdForMaterialId({
  required String materialId,
  required Map<String, Louvor> byPdfId,
  Map<String, ChordMaterial> chordsById = const {},
  List<Louvor> catalog = const [],
}) {
  if (materialId.isEmpty) return null;

  final chord = chordsById[materialId];
  if (chord != null) {
    final gid = chord.groupId.trim();
    return gid.isEmpty ? null : gid;
  }

  final cached = byPdfId[materialId];
  if (cached != null) return cached.effectiveGroupId;

  for (final louvor in catalog) {
    if (louvor.pdfId == materialId) return louvor.effectiveGroupId;
  }
  return null;
}

/// Faixas de [tracks] pertencentes a [groupId], na ordem recebida.
List<AudioTrack> tracksForGroup(String groupId, List<AudioTrack> tracks) {
  final gid = groupId.trim();
  if (gid.isEmpty) return const [];
  return [
    for (final track in tracks)
      if (track.groupId.trim() == gid) track,
  ];
}

/// Ponte partitura → áudio: faixa preferida do louvor [groupId].
///
/// Categoria [kPrimaryAudioCategoria] primeiro; senão a primeira faixa do
/// grupo. `null` se o louvor não tem áudio.
AudioTrack? findAudioForGroup(String groupId, List<AudioTrack> tracks) {
  final matching = tracksForGroup(groupId, tracks);
  if (matching.isEmpty) return null;
  for (final track in matching) {
    if (track.categoria.trim() == kPrimaryAudioCategoria) return track;
  }
  return matching.first;
}
