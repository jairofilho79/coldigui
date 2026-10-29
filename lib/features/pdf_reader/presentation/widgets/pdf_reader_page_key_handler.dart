import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/url_sync_params.dart';
import '../../../app_shell/presentation/widgets/app_shortcuts.dart';
import '../../domain/entities/carousel_reader_position.dart';
import '../providers/pdf_reader_view_settings_provider.dart';
import '../providers/reader_route_params_provider.dart';
import '../utils/pdf_page_keyboard_policy.dart';
import 'go_to_page_dialog.dart';

FocusNode? _activeKeyboardFocusNode;

/// Devolve o foco ao handler de teclado do leitor.
///
/// Depois de clicar num botão da barra 3 o foco fica no botão, e a próxima seta
/// vira foco em vez de página — a barra chama isto para o teclado continuar
/// valendo. No-op quando o leitor não está montado.
void requestPdfReaderKeyboardFocus() {
  final node = _activeKeyboardFocusNode;
  if (node == null || !node.canRequestFocus) return;
  node.requestFocus();
}

/// Captura o teclado/page turner no leitor PDF (UC-11 + atalhos desktop).
///
/// Envolve a área do documento com [Focus] e delega o mapeamento a
/// [PdfPageKeyboardPolicy.actionForKey]. Teclas de página reutilizam o mesmo
/// callback de navegação animada do swipe; teclas de louvor trocam de item no
/// carousel pela mesma rota que as setas da barra 2.
///
/// Teclas fora da política sobem para os atalhos globais ([AppShortcuts]) —
/// é o que faz `F`, `Esc` e `Ctrl+Espaço` funcionarem aqui dentro.
class PdfReaderPageKeyHandler extends ConsumerStatefulWidget {
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
  ConsumerState<PdfReaderPageKeyHandler> createState() =>
      _PdfReaderPageKeyHandlerState();
}

class _PdfReaderPageKeyHandlerState
    extends ConsumerState<PdfReaderPageKeyHandler> {
  late final FocusNode _focusNode = FocusNode(debugLabel: 'pdfReaderKeys');
  var _louvorNavigationInProgress = false;

  @override
  void initState() {
    super.initState();
    _activeKeyboardFocusNode = _focusNode;
  }

  @override
  void dispose() {
    if (identical(_activeKeyboardFocusNode, _focusNode)) {
      _activeKeyboardFocusNode = null;
    }
    _focusNode.dispose();
    super.dispose();
  }

  String? get _currentPdfId {
    final pdfId = ref.read(readerRouteParamsProvider)[UrlSyncParams.pdfId];
    if (pdfId == null || pdfId.isEmpty) return null;
    return pdfId;
  }

  Future<void> _navigateLouvor(CarouselReaderDirection direction) async {
    if (_louvorNavigationInProgress) return;
    _louvorNavigationInProgress = true;
    try {
      await navigateReaderCarouselByKeyboard(
        ref: ref,
        context: context,
        currentPdfId: _currentPdfId,
        direction: direction,
      );
    } finally {
      _louvorNavigationInProgress = false;
    }
  }

  void _navigateToPage(int pageNumber) {
    if (pageNumber == widget.currentPage) return;
    if (pageNumber < 1 || pageNumber > widget.pagesCount) return;
    widget.onNavigateToPage(pageNumber);
  }

  /// `G` — abre [GoToPageDialog] e navega para a página escolhida (spec C16).
  Future<void> _openGoToPageDialog() async {
    final target = await GoToPageDialog.show(
      context,
      pageCount: widget.pagesCount,
      initialPage: widget.currentPage,
    );
    if (target == null || !mounted) return;
    _navigateToPage(target);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!widget.enabled || widget.pageTurnInProgress) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    final action = PdfPageKeyboardPolicy.actionForKey(
      key: event.logicalKey,
      isFirstPage: widget.currentPage <= 1,
      isLastPage:
          widget.pagesCount >= 1 && widget.currentPage >= widget.pagesCount,
      isControlPressed: keyboard.isControlPressed,
      isMetaPressed: keyboard.isMetaPressed,
      isShiftPressed: keyboard.isShiftPressed,
    );

    switch (action) {
      case PdfKeyAction.none:
        return KeyEventResult.ignored;
      case PdfKeyAction.nextPage:
        _navigateToPage(widget.currentPage + 1);
      case PdfKeyAction.previousPage:
        _navigateToPage(widget.currentPage - 1);
      case PdfKeyAction.firstPage:
        _navigateToPage(1);
      case PdfKeyAction.lastPage:
        _navigateToPage(widget.pagesCount);
      case PdfKeyAction.nextLouvor:
        _navigateLouvor(CarouselReaderDirection.next);
      case PdfKeyAction.previousLouvor:
        _navigateLouvor(CarouselReaderDirection.previous);
      case PdfKeyAction.toggleFit:
        if (keyboardFocusIsInsideTextField()) return KeyEventResult.ignored;
        ref.read(pdfReaderViewSettingsProvider.notifier).toggleFitMode();
      case PdfKeyAction.goToPage:
        if (keyboardFocusIsInsideTextField()) return KeyEventResult.ignored;
        unawaited(_openGoToPageDialog());
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        // Clicar no documento devolve o teclado ao leitor depois de um desvio
        // pela barra 3.
        onPointerDown: (_) => _focusNode.requestFocus(),
        child: widget.child,
      ),
    );
  }
}
