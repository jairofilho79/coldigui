import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../coldigom/data/sources/coldigom_catalog_source.dart';
import '../../../coldigom/domain/utils/coldigom_praise_id.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../../data/sources/plpcg_catalog_source.dart';
import '../entities/louvor.dart';
import '../entities/louvor_data_source.dart';
import '../entities/louvor_group.dart';
import 'find_louvor_by_pdf_id.dart';

/// Grupo lógico PLPCG do louvor com [pdfId], ou `null` se órfão ou único.
///
/// A variante que também olhava o cache Coldigom virou
/// `CompositeCatalogSource.groupForMaterial`: o despacho entre os dois acervos
/// vive na porta, não aqui.
LouvorGroup? findLouvorGroupByPdfId(List<Louvor>? catalog, String pdfId) {
  final group = PlpcgCatalogSource(
    catalog: catalog,
  ).findGroupForMaterial(pdfId);
  if (group == null || group.totalMaterials <= 1) return null;
  return group;
}

/// Grupo para o botão layers da barra: inclui áudios/cifras do cache e aceita
/// 1 PDF se [LouvorGroup.totalMaterials] > 1.
///
/// Precedência quando os dois ids chegam (face de áudio): manda a faixa
/// tocando ([audioId]) se o [pdfId] for de **outro** louvor — o chip focado no
/// carousel não tem relação com o que está tocando. Com os dois no mesmo
/// grupo o [pdfId] segue mandando, para não perder PDFs PLPCG do grupo.
///
/// Continua síncrono (a UI decide se mostra o botão durante o build) e por isso
/// usa os métodos síncronos das fontes em vez da porta assíncrona — os caches e
/// o manifest já estão em memória nos dois casos.
LouvorGroup? findSwapMaterialGroup({
  String? pdfId,
  String? audioId,
  List<Louvor>? plpcgCatalog,
  Map<String, Louvor>? coldigomCache,
  Map<String, AudioTrack>? audioCache,
  Map<String, ChordMaterial>? chordCache,
  Map<String, GestureMaterial>? gestureCache,
}) {
  final plpcg = PlpcgCatalogSource(catalog: plpcgCatalog);
  final coldigom = ColdigomCatalogSource(
    louvores: coldigomCache ?? const {},
    audioTracks: audioCache ?? const {},
    chords: chordCache ?? const {},
    gestures: gestureCache ?? const {},
  );
  final tracks = audioCache?.values.toList() ?? const <AudioTrack>[];
  final chords = chordCache?.values.toList() ?? const <ChordMaterial>[];
  final gestures = gestureCache?.values.toList() ?? const <GestureMaterial>[];

  Louvor? louvor;
  if (pdfId != null && pdfId.isNotEmpty) {
    louvor = findLouvorByPdfIdWithColdigom(
      plpcgCatalog,
      pdfId,
      coldigomCache: coldigomCache,
    );
  }

  final playingGroupId = _playingTrackGroupId(audioId, audioCache);
  if (playingGroupId != null &&
      playingGroupId != _pdfIdGroupKey(pdfId, louvor, chordCache, gestureCache)) {
    return _multipleOnly(coldigom.findGroupById(playingGroupId));
  }

  if (louvor != null) {
    final groupKey = _groupKey(louvor);
    if (louvor.source == LouvorDataSource.coldigom) {
      return _multipleOnly(coldigom.findGroupById(groupKey));
    }
    return _groupIfMultiple(
      plpcg.louvoresOfGroup(groupKey),
      tracks,
      chords,
      gestures,
      groupKey,
    );
  }

  // Cifra ou gesto: o id decodifica para `.chord`/`.gesture`, então nenhum
  // [Louvor] casa com ele. O praiseId sai do próprio id — é o mesmo
  // `assets/praises/{id}/…` do PDF.
  if (pdfId != null &&
      pdfId.isNotEmpty &&
      (chordCache?[pdfId] != null || gestureCache?[pdfId] != null)) {
    return _multipleOnly(coldigom.findGroupForMaterial(pdfId));
  }

  if (audioId == null || audioId.isEmpty) return null;
  final track = audioCache?[audioId];
  if (track == null || track.groupId.isEmpty) return null;

  return _multipleOnly(coldigom.findGroupById(track.groupId));
}

/// `groupId` da faixa tocando, ou `null` sem faixa/sem grupo.
String? _playingTrackGroupId(
  String? audioId,
  Map<String, AudioTrack>? audioCache,
) {
  if (audioId == null || audioId.isEmpty) return null;
  final track = audioCache?[audioId];
  if (track == null || track.groupId.isEmpty) return null;
  return track.groupId;
}

/// `groupId` do material [pdfId] (PDF, cifra ou gesto), ou `null` se
/// desconhecido.
String? _pdfIdGroupKey(
  String? pdfId,
  Louvor? louvor,
  Map<String, ChordMaterial>? chordCache, [
  Map<String, GestureMaterial>? gestureCache,
]) {
  if (louvor != null) return _groupKey(louvor);
  if (pdfId == null || pdfId.isEmpty) return null;
  if (chordCache?[pdfId] == null && gestureCache?[pdfId] == null) return null;
  return coldigomPraiseIdFromPdfId(pdfId);
}

String _groupKey(Louvor louvor) {
  if (louvor.source == LouvorDataSource.coldigom) {
    return coldigomPraiseIdFromPdfId(louvor.pdfId) ?? louvor.effectiveGroupId;
  }
  return louvor.effectiveGroupId;
}

/// Descarta o grupo que sobrou com um material só — não há o que trocar.
LouvorGroup? _multipleOnly(LouvorGroup? group) {
  if (group == null || group.totalMaterials <= 1) return null;
  return group;
}

/// Monta o grupo PLPCG de [groupId] e devolve `null` se sobrar um material só.
///
/// [tracks] e [chords] chegam inteiros e são filtrados aqui pelo mesmo
/// [groupId] usado nos PDFs — o acervo PLPCG não tem cifra nem áudio próprios,
/// mas um louvor PLPCG pode ter faixa Coldigom com o mesmo `groupId`.
LouvorGroup? _groupIfMultiple(
  List<Louvor> pdfs,
  List<AudioTrack> tracks,
  List<ChordMaterial> chords,
  List<GestureMaterial> gestures,
  String groupId,
) {
  final matchingTracks = [
    for (final track in tracks)
      if (track.groupId == groupId) track,
  ];
  final matchingChords = [
    for (final chord in chords)
      if (chord.groupId == groupId) chord,
  ];
  final matchingGestures = [
    for (final gesture in gestures)
      if (gesture.groupId == groupId) gesture,
  ];
  if (pdfs.isEmpty &&
      matchingTracks.isEmpty &&
      matchingChords.isEmpty &&
      matchingGestures.isEmpty) {
    return null;
  }
  final groups = LouvorGroup.fromLouvores(
    pdfs,
    audioTracks: matchingTracks,
    chordMaterials: matchingChords,
    gestureMaterials: matchingGestures,
  );
  if (groups.isEmpty) return null;
  return _multipleOnly(groups.first);
}
