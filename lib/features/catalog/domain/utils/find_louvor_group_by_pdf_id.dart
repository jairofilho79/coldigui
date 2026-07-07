import '../entities/louvor.dart';
import '../entities/louvor_data_source.dart';
import '../entities/louvor_group.dart';
import '../../../coldigom/domain/utils/coldigom_praise_id.dart';
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
