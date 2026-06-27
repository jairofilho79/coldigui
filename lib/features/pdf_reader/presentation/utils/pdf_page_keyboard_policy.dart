import 'package:flutter/services.dart';

import 'pdf_page_swipe_policy.dart';

/// Política de navegação por teclado/page turner no leitor (UC-11).
///
/// Mapeia setas direcionais para troca de página. Diferente do swipe,
/// **não** aplica [PdfPageSwipePolicy.canGoToNextPage] / [canGoToPreviousPage]
/// — page turner sempre troca de página, mesmo com zoom/pan horizontal.
abstract final class PdfPageKeyboardPolicy {
  /// Retorna a direção de troca para [key], ou `null` se não mapeada.
  static PdfPageSwipeDirection? directionForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp) {
      return PdfPageSwipeDirection.previous;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown) {
      return PdfPageSwipeDirection.next;
    }
    return null;
  }

  /// Calcula a página destino, ou `null` se a navegação não é possível.
  static int? targetPage({
    required int currentPage,
    required int pagesCount,
    required PdfPageSwipeDirection direction,
  }) {
    if (pagesCount < 1) return null;

    switch (direction) {
      case PdfPageSwipeDirection.next:
        if (currentPage >= pagesCount) return null;
        return currentPage + 1;
      case PdfPageSwipeDirection.previous:
        if (currentPage <= 1) return null;
        return currentPage - 1;
    }
  }
}
