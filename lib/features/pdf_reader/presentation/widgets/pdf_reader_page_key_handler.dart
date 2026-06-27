import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/pdf_page_keyboard_policy.dart';

/// Captura setas direcionais para troca de página no leitor PDF (UC-11).
///
/// Envolve a área do documento com [Focus] e delega mapeamento a
/// [PdfPageKeyboardPolicy]. Reutiliza o mesmo callback de navegação animada
/// do swipe horizontal.
class PdfReaderPageKeyHandler extends StatefulWidget {
  const PdfReaderPageKeyHandler({
    required this.currentPage,
    required this.pagesCount,
    required this.enabled,
    required this.pageTurnInProgress,
    required this.onNavigateToPage,
    required this.child,
    super.key,
  });

  final int currentPage;
  final int pagesCount;

  /// `true` quando o documento está carregado e pronto para navegação.
  final bool enabled;

  /// Bloqueia novas teclas enquanto uma animação de troca está em andamento.
  final bool pageTurnInProgress;

  final Future<void> Function(int pageNumber) onNavigateToPage;
  final Widget child;

  @override
  State<PdfReaderPageKeyHandler> createState() =>
      _PdfReaderPageKeyHandlerState();
}

class _PdfReaderPageKeyHandlerState extends State<PdfReaderPageKeyHandler> {
  late final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!widget.enabled || widget.pageTurnInProgress) {
      return KeyEventResult.ignored;
    }

    final direction = PdfPageKeyboardPolicy.directionForKey(event.logicalKey);
    if (direction == null) return KeyEventResult.ignored;

    final targetPage = PdfPageKeyboardPolicy.targetPage(
      currentPage: widget.currentPage,
      pagesCount: widget.pagesCount,
      direction: direction,
    );
    if (targetPage == null) return KeyEventResult.ignored;

    widget.onNavigateToPage(targetPage);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}
