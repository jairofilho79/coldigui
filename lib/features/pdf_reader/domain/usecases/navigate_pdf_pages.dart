import '../exceptions/invalid_pdf_page_exception.dart';
import '../ports/pdf_reader_controller_port.dart';

/// UC-11 — Navegar páginas do PDF (Fase 2.3).
///
/// Valida limites e delega navegação programática à porta do adapter.
/// Swipe horizontal no leitor usa [PdfPageSwipePolicy] + [PdfxPdfView].
class NavigatePdfPages {
  const NavigatePdfPages(this._controller);

  final PdfReaderControllerPort _controller;

  /// Navega para [targetPage] no intervalo `[1, pagesCount]`.
  Future<void> call({
    required int targetPage,
    required int pagesCount,
  }) async {
    _validatePage(targetPage, pagesCount);
    await _controller.goToPage(targetPage);
  }

  /// Avança para a próxima página, se existir.
  Future<void> nextPage({required int pagesCount}) async {
    final current = _controller.currentPage ?? 1;
    if (current >= pagesCount) return;
    await _controller.nextPage();
  }

  /// Volta para a página anterior, se existir.
  Future<void> previousPage() async {
    final current = _controller.currentPage ?? 1;
    if (current <= 1) return;
    await _controller.previousPage();
  }

  void _validatePage(int page, int pagesCount) {
    if (pagesCount < 1) {
      throw const InvalidPdfPageException('Documento sem páginas');
    }
    if (page < 1 || page > pagesCount) {
      throw InvalidPdfPageException(
        'Página $page fora do intervalo 1–$pagesCount',
      );
    }
  }
}
