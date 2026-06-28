import '../../../catalog/domain/entities/louvor.dart';

/// Chave estável para o mesmo material lógico após substituição no manifest.
String catalogPdfRemapKey(Louvor louvor) =>
    '${louvor.effectiveGroupId}\u0000${louvor.categoria}';

/// Mapa `pdfId antigo → pdfId novo` quando o manifest substitui o PDF de um material.
Map<String, String> computeCatalogPdfIdRemappings({
  required List<Louvor> previousLouvores,
  required List<Louvor> newLouvores,
}) {
  final previousPdfIdByKey = <String, String>{};
  for (final louvor in previousLouvores) {
    previousPdfIdByKey[catalogPdfRemapKey(louvor)] = louvor.pdfId;
  }

  final remappings = <String, String>{};
  for (final louvor in newLouvores) {
    final oldPdfId = previousPdfIdByKey[catalogPdfRemapKey(louvor)];
    if (oldPdfId != null && oldPdfId != louvor.pdfId) {
      remappings[oldPdfId] = louvor.pdfId;
    }
  }
  return remappings;
}

/// Substitui ids obsoletos preservando ordem; ids desconhecidos permanecem.
List<String> remapPdfIdList(
  List<String> pdfIds,
  Map<String, String> remappings,
) {
  if (remappings.isEmpty) return pdfIds;
  return pdfIds.map((id) => remappings[id] ?? id).toList(growable: false);
}
