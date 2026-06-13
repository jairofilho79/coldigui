import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/theme/color_extensions.dart';
import '../utils/pdf_page_swipe_policy.dart';

/// Callback para navegação programática com indicador estável (UC-11).
typedef PdfReaderNavigateToPage = Future<void> Function(int pageNumber);

/// Widget PDFx encapsulado — único ponto de import `pdfx` na presentation (ADR-002).
///
/// Scroll vertical contínuo fixo (`Axis.vertical`). `ValueKey(controller)` evita
/// duas instâncias simultâneas do mesmo controller. Controllers reutilizados do
/// cache LRU exigem `_scheduleReattachIfCached` — PDFx não repopula `_pages` sozinho.
///
/// Swipe horizontal (UC-11): direita→esquerda avança; esquerda→direita volta.
/// O gesto só é reconhecido ao soltar o dedo; no máximo ±1 página em relação
/// à página no início do toque. Usa [Listener] para não competir com pan/pinch
/// do [PdfViewPinch].
class PdfxPdfView extends StatefulWidget {
  const PdfxPdfView({
    required this.controller,
    required this.navigateToPage,
    this.onPageChanged,
    super.key,
  });

  final PdfControllerPinch controller;

  /// Navegação animada; deve passar por [PdfReaderDisplayedPageNotifier].
  final PdfReaderNavigateToPage navigateToPage;

  /// Callback opcional quando a página visível muda (scroll).
  final ValueChanged<int>? onPageChanged;

  @override
  State<PdfxPdfView> createState() => _PdfxPdfViewState();
}

class _PdfxPdfViewState extends State<PdfxPdfView> {
  var _activePointers = 0;
  int? _trackingPointer;
  int? _pageAtPointerDown;
  Offset _accumulatedDelta = Offset.zero;
  var _pageTurnInProgress = false;
  PdfPageSwipeDirection? _swipeFeedbackDirection;
  var _hapticTriggeredForSwipe = false;

  @override
  void initState() {
    super.initState();
    _scheduleReattachIfCached();
  }

  @override
  void didUpdateWidget(covariant PdfxPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _scheduleReattachIfCached();
    }
  }

  /// PDFx `_attach` não repopula `_pages` quando `_document != null` (cache LRU).
  /// Sem isso, voltar a um PDF cacheado deixa o canvas vazio.
  void _scheduleReattachIfCached() {
    final controller = widget.controller;
    if (controller.loadingState.value != PdfLoadingState.success) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!identical(widget.controller, controller)) return;
      if (controller.loadingState.value != PdfLoadingState.success) return;

      try {
        await controller.loadDocument(
          controller.document,
          initialPage: controller.pageListenable.value,
        );
      } on Object {
        // PDFx expõe falhas via loadingState / errorBuilder.
      }
    });
  }

  void _resetTracking() {
    final hadFeedback = _swipeFeedbackDirection != null;
    _trackingPointer = null;
    _pageAtPointerDown = null;
    _accumulatedDelta = Offset.zero;
    _swipeFeedbackDirection = null;
    _hapticTriggeredForSwipe = false;
    if (hadFeedback && mounted) {
      setState(() {});
    }
  }

  PdfPageSwipeDirection? _computeSwipeFeedback() {
    if (_trackingPointer == null || _pageTurnInProgress) return null;

    final direction =
        PdfPageSwipePolicy.activeHorizontalSwipe(_accumulatedDelta);
    if (direction == null) return null;

    final controller = widget.controller;
    switch (direction) {
      case PdfPageSwipeDirection.next:
        if (!PdfPageSwipePolicy.canGoToNextPage(controller)) return null;
      case PdfPageSwipeDirection.previous:
        if (!PdfPageSwipePolicy.canGoToPreviousPage(controller)) return null;
    }
    return direction;
  }

  void _updateSwipeFeedback() {
    final newFeedback = _computeSwipeFeedback();
    if (newFeedback == _swipeFeedbackDirection) return;

    final shouldHaptic = newFeedback != null && !_hapticTriggeredForSwipe;
    setState(() {
      _swipeFeedbackDirection = newFeedback;
      if (shouldHaptic) {
        _hapticTriggeredForSwipe = true;
      }
    });
    if (shouldHaptic) {
      HapticFeedback.lightImpact();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pageTurnInProgress) return;

    _activePointers++;
    if (_activePointers == 1) {
      _trackingPointer = event.pointer;
      _pageAtPointerDown = widget.controller.page;
      _accumulatedDelta = Offset.zero;
      _swipeFeedbackDirection = null;
      _hapticTriggeredForSwipe = false;
    } else {
      _resetTracking();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_trackingPointer != event.pointer || _pageTurnInProgress) return;
    _accumulatedDelta += event.delta;
    _updateSwipeFeedback();
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers = (_activePointers - 1).clamp(0, 10);
    if (_trackingPointer != event.pointer) return;

    final trackingPointer = _trackingPointer;
    final pageAtDown = _pageAtPointerDown;
    final totalDelta = _accumulatedDelta;
    _resetTracking();

    _handleSwipeEnd(
      trackingPointer: trackingPointer,
      pageAtPointerDown: pageAtDown,
      totalDelta: totalDelta,
    );
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers = (_activePointers - 1).clamp(0, 10);
    if (_trackingPointer == event.pointer) {
      _resetTracking();
    }
  }

  Future<void> _handleSwipeEnd({
    required int? trackingPointer,
    required int? pageAtPointerDown,
    required Offset totalDelta,
  }) async {
    if (trackingPointer == null ||
        pageAtPointerDown == null ||
        _pageTurnInProgress) {
      return;
    }
    if (!PdfPageSwipePolicy.isHorizontalSwipe(totalDelta)) return;

    final controller = widget.controller;
    final pagesCount = controller.pagesCount;
    if (pagesCount == null || pagesCount < 1) return;

    final dx = totalDelta.dx;
    final int targetPage;

    if (dx < 0) {
      // Direita→esquerda: próxima página.
      if (!PdfPageSwipePolicy.canGoToNextPage(controller)) return;
      targetPage = pageAtPointerDown + 1;
    } else {
      // Esquerda→direita: página anterior.
      if (!PdfPageSwipePolicy.canGoToPreviousPage(controller)) return;
      targetPage = pageAtPointerDown - 1;
    }

    if (targetPage < 1 || targetPage > pagesCount) return;

    _pageTurnInProgress = true;
    try {
      await widget.navigateToPage(targetPage);
    } finally {
      if (mounted) {
        _pageTurnInProgress = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PdfViewPinch(
            key: ValueKey(widget.controller),
            controller: widget.controller,
            scrollDirection: Axis.vertical,
            onPageChanged: widget.onPageChanged,
            backgroundDecoration: const BoxDecoration(color: AppColors.pdfArea),
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
              pageLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
              errorBuilder: (_, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.toString(),
                    style: const TextStyle(color: AppColors.textLight),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          if (_swipeFeedbackDirection != null)
            IgnorePointer(
              child: PdfHorizontalSwipeIndicator(
                direction: _swipeFeedbackDirection!,
              ),
            ),
        ],
      ),
    );
  }
}

/// Overlay de feedback durante swipe horizontal válido (UC-11 / backlog #14).
@visibleForTesting
class PdfHorizontalSwipeIndicator extends StatelessWidget {
  const PdfHorizontalSwipeIndicator({
    required this.direction,
    super.key,
  });

  final PdfPageSwipeDirection direction;

  static const _indicatorOpacity = 0.35;

  @override
  Widget build(BuildContext context) {
    final isNext = direction == PdfPageSwipeDirection.next;

    return Align(
      alignment: isNext ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Opacity(
          opacity: _indicatorOpacity,
          child: Icon(
            isNext ? Icons.chevron_right : Icons.chevron_left,
            size: 48,
            color: AppColors.gold,
          ),
        ),
      ),
    );
  }
}
