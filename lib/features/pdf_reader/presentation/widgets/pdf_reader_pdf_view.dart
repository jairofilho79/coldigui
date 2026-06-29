import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../data/models/pdf_reader_viewer_handle.dart';
import '../utils/pdf_page_edge_tap_policy.dart';
import '../utils/pdf_page_keyboard_policy.dart';
import '../utils/pdf_page_swipe_policy.dart';
import '../utils/pdf_reader_viewport_policy.dart';
import 'pdf_reader_page_key_handler.dart';

/// Callback para navegação programática com indicador estável (UC-11).
typedef PdfReaderNavigateToPage = Future<void> Function(int pageNumber);

/// Widget pdfrx encapsulado — único ponto de import `pdfrx` na presentation (ADR-002).
///
/// Scroll vertical contínuo (layout padrão pdfrx). `ValueKey(handle)` evita
/// duas instâncias simultâneas do mesmo handle. Handles reutilizados do
/// cache LRU exigem `_scheduleReattachIfCached` via [PdfReaderViewerHandle.reattachIfNeeded].
class PdfReaderPdfView extends StatefulWidget {
  const PdfReaderPdfView({
    required this.handle,
    required this.navigateToPage,
    this.requiresReattach = false,
    this.refreshViewportAfterNavigation,
    this.onPageChanged,
    super.key,
  });

  final PdfReaderViewerHandle handle;

  /// Reattach via `invalidate` só para handles do cache LRU.
  final bool requiresReattach;

  /// Navegação animada; deve passar por [PdfReaderDisplayedPageNotifier].
  final PdfReaderNavigateToPage navigateToPage;

  /// Reaplica fit após troca de página.
  final Future<void> Function()? refreshViewportAfterNavigation;

  /// Callback opcional quando a página visível muda (scroll).
  final ValueChanged<int>? onPageChanged;

  @override
  State<PdfReaderPdfView> createState() => _PdfReaderPdfViewState();
}

class _PdfReaderPdfViewState extends State<PdfReaderPdfView> {
  var _activePointers = 0;
  int? _trackingPointer;
  int? _pageAtPointerDown;
  Offset? _pointerDownLocalPosition;
  Offset _accumulatedDelta = Offset.zero;
  var _pageTurnInProgress = false;
  PdfPageSwipeDirection? _swipeFeedbackDirection;
  var _hapticTriggeredForSwipe = false;
  PdfReaderViewerHandle? _listeningHandle;
  VoidCallback? _loadingStateListener;
  final _reattachGuard = PdfReattachGuard();
  late PdfReaderViewportPolicy _viewportPolicy;

  @override
  void initState() {
    super.initState();
    _viewportPolicy = PdfReaderViewportPolicy(initialPage: widget.handle.page);
    if (widget.requiresReattach) {
      _attachLoadingStateListener(widget.handle);
      _scheduleReattachIfCached();
    }
  }

  @override
  void didUpdateWidget(covariant PdfReaderPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.handle, widget.handle)) {
      _detachLoadingStateListener();
      _viewportPolicy = PdfReaderViewportPolicy(
        initialPage: widget.handle.page,
      );
      _reattachGuard.complete();
      if (widget.requiresReattach) {
        _attachLoadingStateListener(widget.handle);
        _scheduleReattachIfCached();
      }
    } else if (oldWidget.requiresReattach != widget.requiresReattach) {
      if (widget.requiresReattach) {
        _attachLoadingStateListener(widget.handle);
        _scheduleReattachIfCached();
      } else {
        _detachLoadingStateListener();
      }
    }
  }

  @override
  void dispose() {
    _detachLoadingStateListener();
    super.dispose();
  }

  void _attachLoadingStateListener(PdfReaderViewerHandle handle) {
    _listeningHandle = handle;
    _loadingStateListener = () {
      if (handle.loadingState.value == PdfReaderLoadingState.success) {
        _scheduleReattachIfCached();
      }
    };
    handle.loadingState.addListener(_loadingStateListener!);
  }

  void _detachLoadingStateListener() {
    final handle = _listeningHandle;
    final listener = _loadingStateListener;
    if (handle != null && listener != null) {
      handle.loadingState.removeListener(listener);
    }
    _listeningHandle = null;
    _loadingStateListener = null;
  }

  void _scheduleReattachIfCached() {
    if (!widget.requiresReattach) return;

    final handle = widget.handle;
    if (handle.loadingState.value != PdfReaderLoadingState.success) {
      return;
    }
    if (!_reattachGuard.trySchedule()) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _reattachGuard.complete();
      if (!mounted) return;
      if (!identical(widget.handle, handle)) return;
      if (handle.loadingState.value != PdfReaderLoadingState.success) return;

      try {
        await handle.reattachIfNeeded();
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            '[PdfReaderPdfView._scheduleReattachIfCached] $error\n$stackTrace',
          );
        }
      }
    });
  }

  void _scheduleViewportRefresh({required int pageNumber}) {
    if (!_viewportPolicy.shouldScheduleRefresh(pageNumber)) return;

    final refresh = widget.refreshViewportAfterNavigation;
    if (refresh == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await refresh();
    });
  }

  void _handleVisiblePageChanged(int? pageNumber) {
    if (pageNumber == null) return;
    widget.handle.onPageChanged(pageNumber);
    widget.onPageChanged?.call(pageNumber);
    _scheduleViewportRefresh(pageNumber: pageNumber);
  }

  void _resetTracking() {
    final hadFeedback = _swipeFeedbackDirection != null;
    _trackingPointer = null;
    _pageAtPointerDown = null;
    _pointerDownLocalPosition = null;
    _accumulatedDelta = Offset.zero;
    _swipeFeedbackDirection = null;
    _hapticTriggeredForSwipe = false;
    if (hadFeedback && mounted) {
      setState(() {});
    }
  }

  PdfPageSwipeDirection? _computeSwipeFeedback() {
    if (_trackingPointer == null || _pageTurnInProgress) return null;

    final direction = PdfPageSwipePolicy.activeHorizontalSwipe(
      _accumulatedDelta,
    );
    if (direction == null) return null;

    final snapshot = widget.handle.viewportSnapshot();
    if (snapshot == null) return null;

    switch (direction) {
      case PdfPageSwipeDirection.next:
        if (!PdfPageSwipePolicy.canGoToNextPage(snapshot)) return null;
      case PdfPageSwipeDirection.previous:
        if (!PdfPageSwipePolicy.canGoToPreviousPage(snapshot)) return null;
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
      _pageAtPointerDown = widget.handle.page;
      _pointerDownLocalPosition = event.localPosition;
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
    final pointerDownLocalPosition = _pointerDownLocalPosition;
    final totalDelta = _accumulatedDelta;
    _resetTracking();

    _handleSwipeEnd(
      trackingPointer: trackingPointer,
      pageAtPointerDown: pageAtDown,
      totalDelta: totalDelta,
    );

    _handleEdgeTapEnd(
      pointerDownLocalPosition: pointerDownLocalPosition,
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

    final snapshot = widget.handle.viewportSnapshot();
    if (snapshot == null) return;

    final pagesCount = widget.handle.pagesCount;
    if (pagesCount == null || pagesCount < 1) return;

    final dx = totalDelta.dx;
    final int targetPage;

    if (dx < 0) {
      if (!PdfPageSwipePolicy.canGoToNextPage(snapshot)) return;
      targetPage = pageAtPointerDown + 1;
    } else {
      if (!PdfPageSwipePolicy.canGoToPreviousPage(snapshot)) return;
      targetPage = pageAtPointerDown - 1;
    }

    if (targetPage < 1 || targetPage > pagesCount) return;

    await _navigateToPageWithLock(targetPage);
  }

  Future<void> _handleEdgeTapEnd({
    required Offset? pointerDownLocalPosition,
    required Offset totalDelta,
  }) async {
    if (pointerDownLocalPosition == null || _pageTurnInProgress) return;
    if (!widget.handle.isViewerReady) return;
    if (!PdfPageEdgeTapPolicy.isStrictTap(totalDelta)) return;

    final canvasWidth = _canvasWidth;
    if (canvasWidth == null || canvasWidth <= 0) return;

    final direction = PdfPageEdgeTapPolicy.directionForDownPosition(
      localX: pointerDownLocalPosition.dx,
      canvasWidth: canvasWidth,
    );
    if (direction == null) return;

    final pagesCount = widget.handle.pagesCount;
    if (pagesCount == null || pagesCount < 1) return;

    final targetPage = PdfPageKeyboardPolicy.targetPage(
      currentPage: widget.handle.page,
      pagesCount: pagesCount,
      direction: direction,
    );
    if (targetPage == null) return;

    await _navigateToPageWithLock(targetPage);
  }

  double? _canvasWidth;

  Future<void> _navigateToPageWithLock(int targetPage) async {
    if (_pageTurnInProgress) return;
    setState(() => _pageTurnInProgress = true);
    try {
      await widget.navigateToPage(targetPage);
      _scheduleViewportRefresh(pageNumber: targetPage);
    } finally {
      if (mounted) {
        setState(() => _pageTurnInProgress = false);
      }
    }
  }

  Widget _buildPdfContent() {
    final handle = widget.handle;
    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasWidth = constraints.maxWidth;
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PdfViewer(
                handle.documentRef,
                key: ValueKey(handle),
                controller: handle.viewerController,
                params: PdfViewerParams(
                  backgroundColor: AppColors.pdfArea,
                  onViewerReady: (_, _) => handle.markViewerReady(),
                  onPageChanged: _handleVisiblePageChanged,
                  loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    );
                  },
                  errorBannerBuilder: (context, error, stackTrace, reload) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          error.toString(),
                          style: const TextStyle(color: AppColors.textLight),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final handle = widget.handle;

    return ValueListenableBuilder<PdfReaderLoadingState>(
      valueListenable: handle.loadingState,
      builder: (context, loadingState, _) {
        return ValueListenableBuilder<int>(
          valueListenable: handle.pageListenable,
          builder: (context, currentPage, _) {
            return PdfReaderPageKeyHandler(
              currentPage: currentPage,
              pagesCount: handle.pagesCount ?? 0,
              enabled: loadingState == PdfReaderLoadingState.success,
              pageTurnInProgress: _pageTurnInProgress,
              onNavigateToPage: _navigateToPageWithLock,
              child: _buildPdfContent(),
            );
          },
        );
      },
    );
  }
}

/// Evita agendar múltiplos reattach simultâneos.
@visibleForTesting
class PdfReattachGuard {
  var _scheduled = false;

  bool trySchedule() {
    if (_scheduled) return false;
    _scheduled = true;
    return true;
  }

  void complete() => _scheduled = false;
}

/// Overlay de feedback durante swipe horizontal válido (UC-11 / backlog #14).
@visibleForTesting
class PdfHorizontalSwipeIndicator extends StatelessWidget {
  const PdfHorizontalSwipeIndicator({required this.direction, super.key});

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
