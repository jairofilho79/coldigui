import '../../../audio_player/domain/entities/audio_track.dart';
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

/// Grupo para o botão layers da barra: inclui áudios do cache e aceita 1 PDF
/// se [LouvorGroup.totalMaterials] > 1.
LouvorGroup? findSwapMaterialGroup({
  String? pdfId,
  String? audioId,
  List<Louvor>? plpcgCatalog,
  Map<String, Louvor>? coldigomCache,
  Map<String, AudioTrack>? audioCache,
}) {
  final tracks = audioCache?.values.toList() ?? const <AudioTrack>[];
  Louvor? louvor;
  if (pdfId != null && pdfId.isNotEmpty) {
    louvor = findLouvorByPdfIdWithColdigom(
      plpcgCatalog,
      pdfId,
      coldigomCache: coldigomCache,
    );
  }

  if (louvor != null) {
    final pdfs = _pdfSiblings(
      louvor,
      _siblingCatalog(louvor, plpcgCatalog, coldigomCache),
    );
    final gid = _groupKey(louvor);
    final matchingTracks = [
      for (final track in tracks)
        if (track.groupId == gid) track,
    ];
    return _groupIfMultiple(pdfs, matchingTracks);
  }

  if (audioId == null || audioId.isEmpty) return null;
  final track = audioCache?[audioId];
  if (track == null || track.groupId.isEmpty) return null;

  final gid = track.groupId;
  final pdfs = <Louvor>[
    if (coldigomCache != null)
      for (final item in coldigomCache.values)
        if (item.effectiveGroupId == gid) item,
  ];
  final matchingTracks = [
    for (final item in tracks)
      if (item.groupId == gid) item,
  ];
  return _groupIfMultiple(pdfs, matchingTracks);
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

LouvorGroup? _groupIfMultiple(List<Louvor> pdfs, List<AudioTrack> tracks) {
  if (pdfs.isEmpty && tracks.isEmpty) return null;
  final groups = LouvorGroup.fromLouvores(pdfs, audioTracks: tracks);
  if (groups.isEmpty) return null;
  final group = groups.first;
  if (group.totalMaterials <= 1) return null;
  return group;
}
