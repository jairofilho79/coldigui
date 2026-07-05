import '../entities/louvor.dart';
import '../entities/louvor_group.dart';
import 'find_louvor_by_pdf_id.dart';

/// Grupo lógico do louvor com [pdfId], ou `null` se órfão ou material único.
LouvorGroup? findLouvorGroupByPdfId(List<Louvor>? catalog, String pdfId) {
  final louvor = findLouvorByPdfId(catalog, pdfId);
  if (louvor == null) return null;
  final siblings = catalog!
      .where((l) => l.effectiveGroupId == louvor.effectiveGroupId)
      .toList();
  if (siblings.length <= 1) return null;
  return LouvorGroup.fromLouvores(siblings).first;
}
