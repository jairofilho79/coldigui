/// Resultado do resolver local-first (Fase 3.2).
///
/// Diferente de [OfflinePdfEntry], que representa metadados do índice Isar.
/// Consumido por [OpenPdfInReader] e [PdfrxViewerAdapter] na Fase 3.4.
class LocalPdfSource {
  const LocalPdfSource({
    required this.pdfId,
    required this.absolutePath,
    required this.fromCache,
  });

  /// Identificador Base64 URL-safe do path relativo (manifest).
  final String pdfId;

  /// Path absoluto em `documents/plpcg_pdfs/`.
  final String absolutePath;

  /// `true` se veio de [OfflinePdfRepository.lookup]; `false` após fetch on-demand.
  final bool fromCache;
}
