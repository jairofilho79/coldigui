import '../entities/pdf_reader_preferences.dart';

/// Porta de navegação e zoom do leitor — implementada por [PdfxViewerAdapter].
///
/// Mantém o domínio livre de dependência em `pdfx` (ADR-002).
abstract class PdfReaderControllerPort {
  /// Página atual (1-based) ou `null` se o controller ainda não está pronto.
  int? get currentPage;

  /// Total de páginas ou `null` se o documento ainda não carregou.
  int? get pagesCount;

  /// Navega para [pageNumber] (1-based).
  Future<void> goToPage(int pageNumber);

  /// Avança uma página.
  Future<void> nextPage();

  /// Volta uma página.
  Future<void> previousPage();

  /// Aplica modo de encaixe no viewport.
  Future<void> applyFitMode(PdfFitMode mode);
}
