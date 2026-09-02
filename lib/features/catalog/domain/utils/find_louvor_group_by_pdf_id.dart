import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../coldigom/domain/utils/coldigom_praise_id.dart';
import '../entities/louvor.dart';
import '../entities/louvor_data_source.dart';
import '../entities/louvor_group.dart';
import 'find_louvor_by_pdf_id.dart';

/// Grupo lógico do louvor com [pdfId], ou `null` se órfão ou material único.
LouvorGroup? findLouvorGroupByPdfId(List<Louvor>? catalog, String pdfId) {
  final louvor = findLouvorByPdfId(catalog, pdfId);
  if (louvor == null) return null;
  return _groupFromSiblings(
    louvor,
    catalog!.where((l) => l.source == louvor.source),
  );
}

/// Grupo lógico — manifest PLPCG + cache coldigom, sem misturar fontes.
LouvorGroup? findLouvorGroupByPdfIdWithColdigom(
  List<Louvor>? plpcgCatalog,
  String pdfId, {
  Map<String, Louvor>? coldigomCache,
}) {
  final louvor = findLouvorByPdfIdWithColdigom(
    plpcgCatalog,
    pdfId,
    coldigomCache: coldigomCache,
  );
  if (louvor == null) return null;

  final siblings = <Louvor>[];
  if (louvor.source == LouvorDataSource.plpcg && plpcgCatalog != null) {
    siblings.addAll(
      plpcgCatalog.where((l) => l.source == LouvorDataSource.plpcg),
    );
  } else if (louvor.source == LouvorDataSource.coldigom &&
      coldigomCache != null) {
    siblings.addAll(coldigomCache.values);
  }

  return _groupFromSiblings(louvor, siblings);
}

LouvorGroup? _groupFromSiblings(Louvor louvor, Iterable<Louvor> candidates) {
  if (louvor.source == LouvorDataSource.coldigom) {
    final praiseId = coldigomPraiseIdFromPdfId(louvor.pdfId);
    if (praiseId == null) return null;
    final samePraise = candidates
        .where(
          (l) =>
              l.source == LouvorDataSource.coldigom &&
              coldigomPraiseIdFromPdfId(l.pdfId) == praiseId,
        )
        .toList();
    if (samePraise.length <= 1) return null;
    return LouvorGroup.fromLouvores(samePraise).first;
  }

  final gid = louvor.effectiveGroupId;
  final sameGroup = candidates
      .where((l) => l.source == louvor.source && l.effectiveGroupId == gid)
      .toList();
  if (sameGroup.length <= 1) return null;
  return LouvorGroup.fromLouvores(sameGroup).first;
}

/// Grupo para o botão layers da barra: inclui áudios/cifras do cache e aceita
/// 1 PDF se [LouvorGroup.totalMaterials] > 1.
///
/// Precedência quando os dois ids chegam (face de áudio): manda a faixa
/// tocando ([audioId]) se o [pdfId] for de **outro** louvor — o chip focado no
/// carousel não tem relação com o que está tocando. Com os dois no mesmo
/// grupo o [pdfId] segue mandando, para não perder PDFs PLPCG do grupo.
LouvorGroup? findSwapMaterialGroup({
  String? pdfId,
  String? audioId,
  List<Louvor>? plpcgCatalog,
  Map<String, Louvor>? coldigomCache,
  Map<String, AudioTrack>? audioCache,
  Map<String, ChordMaterial>? chordCache,
}) {
  final tracks = audioCache?.values.toList() ?? const <AudioTrack>[];
  final chords = chordCache?.values.toList() ?? const <ChordMaterial>[];
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
      playingGroupId != _pdfIdGroupKey(pdfId, louvor, chordCache)) {
    return _groupIfMultiple(
      _coldigomSiblingPdfs(coldigomCache, playingGroupId),
      tracks,
      chords,
      playingGroupId,
    );
  }

  if (louvor != null) {
    final pdfs = _pdfSiblings(
      louvor,
      _siblingCatalog(louvor, plpcgCatalog, coldigomCache),
    );
    return _groupIfMultiple(pdfs, tracks, chords, _groupKey(louvor));
  }

  // Cifra: o id decodifica para `.chord`, então nenhum [Louvor] casa com ele.
  // O praiseId sai do próprio id — é o mesmo `assets/praises/{id}/…` do PDF.
  if (pdfId != null && pdfId.isNotEmpty) {
    final chordGid = coldigomPraiseIdFromPdfId(pdfId);
    if (chordGid != null && chordCache?[pdfId] != null) {
      return _groupIfMultiple(
        _coldigomSiblingPdfs(coldigomCache, chordGid),
        tracks,
        chords,
        chordGid,
      );
    }
  }

  if (audioId == null || audioId.isEmpty) return null;
  final track = audioCache?[audioId];
  if (track == null || track.groupId.isEmpty) return null;

  final gid = track.groupId;
  return _groupIfMultiple(
    _coldigomSiblingPdfs(coldigomCache, gid),
    tracks,
    chords,
    gid,
  );
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

/// `groupId` do material [pdfId] (PDF ou cifra), ou `null` se desconhecido.
String? _pdfIdGroupKey(
  String? pdfId,
  Louvor? louvor,
  Map<String, ChordMaterial>? chordCache,
) {
  if (louvor != null) return _groupKey(louvor);
  if (pdfId == null || pdfId.isEmpty) return null;
  final chord = chordCache?[pdfId];
  if (chord == null) return null;
  return coldigomPraiseIdFromPdfId(pdfId);
}

List<Louvor> _coldigomSiblingPdfs(
  Map<String, Louvor>? coldigomCache,
  String groupId,
) {
  return <Louvor>[
    if (coldigomCache != null)
      for (final item in coldigomCache.values)
        if (item.effectiveGroupId == groupId) item,
  ];
}

Iterable<Louvor> _siblingCatalog(
  Louvor louvor,
  List<Louvor>? plpcgCatalog,
  Map<String, Louvor>? coldigomCache,
) {
  if (louvor.source == LouvorDataSource.plpcg) {
    return plpcgCatalog ?? const [];
  }
  return coldigomCache?.values ?? const [];
}

String _groupKey(Louvor louvor) {
  if (louvor.source == LouvorDataSource.coldigom) {
    return coldigomPraiseIdFromPdfId(louvor.pdfId) ?? louvor.effectiveGroupId;
  }
  return louvor.effectiveGroupId;
}

List<Louvor> _pdfSiblings(Louvor louvor, Iterable<Louvor> candidates) {
  if (louvor.source == LouvorDataSource.coldigom) {
    final praiseId = coldigomPraiseIdFromPdfId(louvor.pdfId);
    if (praiseId == null) return [louvor];
    return [
      for (final item in candidates)
        if (item.source == LouvorDataSource.coldigom &&
            coldigomPraiseIdFromPdfId(item.pdfId) == praiseId)
          item,
    ];
  }
  final gid = louvor.effectiveGroupId;
  return [
    for (final item in candidates)
      if (item.source == louvor.source && item.effectiveGroupId == gid) item,
  ];
}

/// Monta o grupo de [groupId] e devolve `null` se sobrar um material só.
///
/// [tracks] e [chords] chegam inteiros e são filtrados aqui pelo mesmo
/// [groupId] usado nos PDFs — é o que impede a aba Cifras de sumir por um
/// filtro esquecido em um dos três ramos de [findSwapMaterialGroup].
LouvorGroup? _groupIfMultiple(
  List<Louvor> pdfs,
  List<AudioTrack> tracks,
  List<ChordMaterial> chords,
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
  if (pdfs.isEmpty && matchingTracks.isEmpty && matchingChords.isEmpty) {
    return null;
  }
  final groups = LouvorGroup.fromLouvores(
    pdfs,
    audioTracks: matchingTracks,
    chordMaterials: matchingChords,
  );
  if (groups.isEmpty) return null;
  final group = groups.first;
  if (group.totalMaterials <= 1) return null;
  return group;
}
