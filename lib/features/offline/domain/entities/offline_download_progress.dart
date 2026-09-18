/// Progresso do download em massa UC-09 (PDF a PDF) para a UI.
class OfflineDownloadProgress {
  const OfflineDownloadProgress({
    required this.currentCategory,
    required this.donePdfs,
    required this.totalPdfs,
  });

  /// Rótulo do que está a baixar — as categorias pedidas, separadas por `, `.
  final String currentCategory;

  /// PDFs concluídos (baixados ou falhados) nesta execução.
  final int donePdfs;

  /// PDFs faltantes no início da execução.
  final int totalPdfs;

  double get pdfFraction => totalPdfs == 0 ? 0 : donePdfs / totalPdfs;
}
