import '../utils/coldigom_pdf_id_from_manifest_pdf.dart';
import 'louvor.dart';

/// Índices do manifest que ligam o espaço de ids legado ao Coldigom.
///
/// Construído **uma vez por manifest** (`manifestMaterialAliasesProvider`).
/// Vazio ([empty]) enquanto o manifest não tem `praiseId` — cache anterior à
/// migração ou ainda a carregar —, e nesse caso o composite se comporta como
/// antes da fusão.
final class ManifestMaterialAliases {
  const ManifestMaterialAliases({
    required this.praiseIds,
    required this.byMaterialId,
    required this.legacyPdfIdByColdigomPdfId,
  });

  static const empty = ManifestMaterialAliases(
    praiseIds: {},
    byMaterialId: {},
    legacyPdfIdByColdigomPdfId: {},
  );

  /// Praises cobertos pelo manifest — «um card por praise» (spec D3).
  final Set<String> praiseIds;

  /// `materialId` Coldigom → entrada do manifest (primeira ocorrência: dois
  /// `pdfId` legados podem apontar o mesmo ficheiro, F4).
  final Map<String, Louvor> byMaterialId;

  /// Id Coldigom nativo (`encodePdfId('assets/praises/…')`) → `pdfId` legado.
  /// É por aqui que uma playlist recente com ids Coldigom de materiais
  /// cobertos continua a abrir sem rede (spec D4/§7).
  final Map<String, String> legacyPdfIdByColdigomPdfId;

  bool get isEmpty => praiseIds.isEmpty;

  /// `true` quando [groupId] é um praise coberto pelo manifest.
  bool coversPraise(String groupId) => praiseIds.contains(groupId);

  /// `true` quando [coldigomPdfId] é um PDF que o manifest também lista.
  bool coversColdigomPdf(String coldigomPdfId) =>
      legacyPdfIdByColdigomPdfId.containsKey(coldigomPdfId);

  factory ManifestMaterialAliases.fromLouvores(List<Louvor> louvores) {
    final praiseIds = <String>{};
    final byMaterialId = <String, Louvor>{};
    final legacyByColdigom = <String, String>{};
    for (final louvor in louvores) {
      final praiseId = louvor.praiseId;
      if (praiseId == null) continue;
      praiseIds.add(praiseId);
      final materialId = louvor.materialId;
      if (materialId != null) {
        byMaterialId.putIfAbsent(materialId, () => louvor);
      }
      final coldigomPdfId = coldigomPdfIdFromManifestPdf(louvor.pdf);
      if (coldigomPdfId != null) {
        legacyByColdigom.putIfAbsent(coldigomPdfId, () => louvor.pdfId);
      }
    }
    if (praiseIds.isEmpty) return empty;
    return ManifestMaterialAliases(
      praiseIds: Set.unmodifiable(praiseIds),
      byMaterialId: Map.unmodifiable(byMaterialId),
      legacyPdfIdByColdigomPdfId: Map.unmodifiable(legacyByColdigom),
    );
  }
}
