import 'package:flutter/services.dart';

import 'pdf_page_swipe_policy.dart';

/// Ação de teclado resolvida no leitor PDF (UC-11 / atalhos desktop).
///
/// [nextLouvor] / [previousLouvor] saem do documento e trocam de item no
/// carousel; [none] significa "não é minha tecla" — o handler deixa o evento
/// subir para os atalhos globais ([AppShortcuts]).
enum PdfKeyAction {
  nextPage,
  previousPage,
  firstPage,
  lastPage,
  nextLouvor,
  previousLouvor,
  none,
}

/// Política de navegação por teclado/page turner no leitor (UC-11).
///
/// Mapeia setas direcionais para troca de página. Diferente do swipe,
/// **não** aplica [PdfPageSwipePolicy.canGoToNextPage] / [canGoToPreviousPage]
/// — page turner sempre troca de página, mesmo com zoom/pan horizontal.
abstract final class PdfPageKeyboardPolicy {
  /// Resolve a ação de teclado do leitor a partir da tecla e do contexto.
  ///
  /// **Pedaleira:** `→`/`PageDown` na última página e `←`/`PageUp` na primeira
  /// saltam para o louvor vizinho, para o músico virar o repertório inteiro sem
  /// tirar o pé do pedal. `Espaço` fica restrito à página — quem quiser
  /// play/pause dentro do leitor usa `Ctrl+Espaço`, que esta política devolve
  /// como [PdfKeyAction.none] justamente para o atalho global tratar.
  ///
  /// `Ctrl+N` / `Ctrl+P` são do navegador (nova janela / imprimir): só o `N` e
  /// o `P` secos trocam de louvor.
  static PdfKeyAction actionForKey({
    required LogicalKeyboardKey key,
    required bool isFirstPage,
    required bool isLastPage,
    bool isControlPressed = false,
    bool isMetaPressed = false,
    bool isShiftPressed = false,
  }) {
    final louvorModifier = isControlPressed || isMetaPressed;

    if (key == LogicalKeyboardKey.home) return PdfKeyAction.firstPage;
    if (key == LogicalKeyboardKey.end) return PdfKeyAction.lastPage;

    if (key == LogicalKeyboardKey.keyN) {
      return louvorModifier ? PdfKeyAction.none : PdfKeyAction.nextLouvor;
    }
    if (key == LogicalKeyboardKey.keyP) {
      return louvorModifier ? PdfKeyAction.none : PdfKeyAction.previousLouvor;
    }

    if (key == LogicalKeyboardKey.space) {
      if (louvorModifier) return PdfKeyAction.none;
      return isShiftPressed ? PdfKeyAction.previousPage : PdfKeyAction.nextPage;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (louvorModifier) return PdfKeyAction.nextLouvor;
      return isLastPage ? PdfKeyAction.nextLouvor : PdfKeyAction.nextPage;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (louvorModifier) return PdfKeyAction.previousLouvor;
      return isFirstPage
          ? PdfKeyAction.previousLouvor
          : PdfKeyAction.previousPage;
    }

    if (key == LogicalKeyboardKey.pageDown) {
      return isLastPage ? PdfKeyAction.nextLouvor : PdfKeyAction.nextPage;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      return isFirstPage
          ? PdfKeyAction.previousLouvor
          : PdfKeyAction.previousPage;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      return louvorModifier ? PdfKeyAction.none : PdfKeyAction.nextPage;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return louvorModifier ? PdfKeyAction.none : PdfKeyAction.previousPage;
    }

    return PdfKeyAction.none;
  }

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
