import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/theme/color_extensions.dart';
import '../utils/pdf_page_swipe_policy.dart';

/// Callback para navegação programática com indicador estável (UC-11).
typedef PdfReaderNavigateToPage = Future<void> Function(int pageNumber);

/// Widget PDFx encapsulado — único ponto de import `pdfx` na presentation (ADR-002).
///
/// Scroll vertical contínuo fixo (`Axis.vertical`). `ValueKey(controller)` força
/// `initState` limpo no PDFx a cada sessão.
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

  void _resetTracking() {
    _trackingPointer = null;
    _pageAtPointerDown = null;
    _accumulatedDelta = Offset.zero;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pageTurnInProgress) return;

    _activePointers++;
    if (_activePointers == 1) {
      _trackingPointer = event.pointer;
      _pageAtPointerDown = widget.controller.page;
      _accumulatedDelta = Offset.zero;
    } else {
      _resetTracking();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_trackingPointer != event.pointer || _pageTurnInProgress) return;
    _accumulatedDelta += event.delta;
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
      child: PdfViewPinch(
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
    );
  }
}
