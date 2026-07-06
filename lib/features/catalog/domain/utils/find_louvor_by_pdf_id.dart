import '../../../../core/utils/pdf_id_codec.dart';
import '../entities/louvor.dart';
import '../entities/louvor_data_source.dart';

/// Lookup O(n) de louvor no manifest PLPCG por [pdfId].
///
/// Retorna `null` se [catalog] for `null` ou se o id for órfão.
/// Para coldigom, use [findLouvorByPdfIdWithColdigom].
Louvor? findLouvorByPdfId(List<Louvor>? catalog, String pdfId) {
  if (catalog == null) return null;
  for (final louvor in catalog) {
    if (louvor.pdfId == pdfId) return louvor;
  }
  return null;
}

/// Lookup unificado — manifest PLPCG + cache coldigom opcional.
Louvor? findLouvorByPdfIdWithColdigom(
  List<Louvor>? plpcgCatalog,
  String pdfId, {
  Map<String, Louvor>? coldigomCache,
}) {
  final fromPlpcg = findLouvorByPdfId(plpcgCatalog, pdfId);
  if (fromPlpcg != null) return fromPlpcg;
  return coldigomCache?[pdfId];
}

/// Resolve [LouvorDataSource] para um [pdfId] com caches disponíveis.
LouvorDataSource resolveLouvorDataSource(
  String pdfId, {
  List<Louvor>? plpcgCatalog,
  Map<String, Louvor>? coldigomCache,
}) {
  final louvor = findLouvorByPdfIdWithColdigom(
    plpcgCatalog,
    pdfId,
    coldigomCache: coldigomCache,
  );
  if (louvor != null) return louvor.source;
  return louvorDataSourceFromPdfId(pdfId);
}
