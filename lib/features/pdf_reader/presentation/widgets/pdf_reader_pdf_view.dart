import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/platform/platform_capabilities_provider.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../data/models/pdf_reader_viewer_handle.dart';
import '../providers/pdf_reader_view_settings_provider.dart';
import '../utils/pdf_page_edge_tap_policy.dart';
import '../utils/pdf_page_keyboard_policy.dart';
import '../utils/pdf_page_swipe_policy.dart';
import '../utils/pdf_render_scale_policy.dart';
import '../utils/pdf_spread_layout.dart';
import 'pdf_reader_page_key_handler.dart';

/// Callback para navegação programática com indicador estável (UC-11).
typedef PdfReaderNavigateToPage = Future<void> Function(int pageNumber);

/// Teto de bytes de imagem cacheados em memória na web — 64 MiB (spec A.13
/// dizia 32 MiB, calibrados para preview a 2,78×). Spread = duas páginas A5
/// (420×586 pt) a 3× ≈ 1260×1758 px × 4 B ≈ 8,9 MB cada, mais os tiles do
/// pinch; com 32 MiB o par visível era evictado e re-renderizado ao voltar
/// (diagnóstico pdfrx, Fase 1.3).
const kPdfWebMaxImageBytesCachedOnMemory = 64 << 20;

/// Provider de tamanho do pdfrx com o preview de cada página rasterizado a
/// [PdfRenderScalePolicy.ceiling] (default do pacote: 200/72 ≈ 2,78×). Com o
/// teto igual ao da política, o preview já é a imagem final na maioria dos
/// zooms e os tiles «real size» só entram em pinch forte. Precisa ser `const`:
/// `PdfViewerParams.doChangesRequireReload` compara o provider por `==`.
/// Demais campos (maxScale 8, minScale 0.1, fit alternativo como mínimo) são
/// os defaults que o app já usava.
const kPdfReaderSizeDelegateProvider = PdfViewerSizeDelegateProviderLegacy(
  onePassRenderingScaleThreshold: PdfRenderScalePolicy.ceiling,
);

/// Monta os [PdfViewerParams] do leitor — função pura para os testes lerem
/// cada parâmetro sem montar um `PdfViewer` (diagnóstico pdfrx, Fase 1).
///
/// [scrollPhysics] vem de `PdfViewerParams.getScrollPhysics(context)` no
/// `build` (precisa de `BuildContext`); [layoutPages] é o spread ou `null`.
@visibleForTesting
PdfViewerParams buildPdfReaderViewerParams({
  required bool isWeb,
  required ScrollPhysics scrollPhysics,
  required PdfViewerReadyCallback onViewerReady,
  required PdfPageChangedCallback onPageChanged,
  PdfPageLayoutFunction? layoutPages,
}) {
  return PdfViewerParams(
    backgroundColor: AppColors.pdfArea,
    onViewerReady: onViewerReady,
    onPageChanged: onPageChanged,
    layoutPages: layoutPages,
    // Fase 1.2 — partitura escaneada não tem texto selecionável nem
    // anotações. Com seleção ligada (default) o pdfrx carrega o texto
    // estruturado de toda página no cacheExtent, no mesmo worker que
    // renderiza, e instala o reconhecedor de long-press. Desligada, o menu
    // de contexto padrão fica vazio — long-press não abre nada.
    textSelectionParams: const PdfTextSelectionParams(enabled: false),
    // Sem FPDF_FFLDraw por página.
    annotationRenderingMode: PdfAnnotationRenderingMode.none,
    // A sombra default é um blur por página em todo frame do CustomPaint.
    pageDropShadow: null,
    // Deixa o PDFium manter o JPEG decodificado entre renders (scans).
    limitRenderingCache: false,
    // Fase 1.3 — uma política de escala para todas as plataformas (antes só
    // a web tinha teto, e sem o 3.0).
    sizeDelegateProvider: kPdfReaderSizeDelegateProvider,
    getPageRenderingScale: (context, page, controller, estimatedScale) =>
        PdfRenderScalePolicy.resolve(
          estimatedScale: estimatedScale,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
    maxImageBytesCachedOnMemory: isWeb
        ? kPdfWebMaxImageBytesCachedOnMemory
        : const PdfViewerParams().maxImageBytesCachedOnMemory,
    // Fase 1.4 — física da plataforma (bounce iOS / overscroll fixo Android;
    // #677 corrigido em 2.4.8) e roda/trackpad com inércia em vez de saltos
    // de 20% por tick.
    scrollPhysics: scrollPhysics,
    interactionDelegateProvider:
        const PdfViewerScrollInteractionDelegateProviderPhysics(),
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
  );
}

/// Widget pdfrx encapsulado — pontos de import `pdfrx` na presentation
/// restritos a este arquivo ([buildPdfReaderViewerParams] concentra os
/// parâmetros do viewer — diagnóstico pdfrx, Fase 1) e a
/// [spreadPageLayout]/[defaultPdfPageLayout] (ADR-002; o layout de páginas em
/// spread, spec A.4, exige os tipos `PdfPage`/`PdfPageLayout`/`PdfViewerParams`
/// do pacote).
///
/// Scroll vertical contínuo (layout padrão pdfrx) ou duas páginas lado a lado
/// em viewport largo, automático via `pdfReaderEffectiveSpreadEnabledProvider`
/// (spec A.4 C8; onda 4.1 removeu a preferência do usuário).
/// `ValueKey(handle)` evita duas instâncias simultâneas do mesmo handle.
/// Handles reutilizados do cache LRU exigem `_scheduleReattachIfCached` via
/// [PdfReaderViewerHandle.reattachIfNeeded].
class PdfReaderPdfView extends ConsumerStatefulWidget {
  const PdfReaderPdfView({
    required this.handle,
    required this.navigateToPage,
    this.requiresReattach = false,
    this.onPageChanged,
    this.onViewerReady,
    super.key,
  });

  final PdfReaderViewerHandle handle;

  /// Reattach via `invalidate` só para handles do cache LRU.
  final bool requiresReattach;

  /// Navegação animada via [PdfReaderViewerHandle.animateToPage].
  final PdfReaderNavigateToPage navigateToPage;

  /// Callback opcional quando a página visível muda (scroll).
  final ValueChanged<int>? onPageChanged;

  /// Notifica (uma vez por [handle], pós-frame) quando `handle.loadingState`
  /// atinge [PdfReaderLoadingState.success] — dispara no momento real em que
  /// o viewer pdfrx anexa o controller, não num post-frame "cego" agendado
  /// antes disso (Important 2, onda 4: restauração da última página e fit
  /// inicial dependiam de um post-frame que corria cedo demais).
  final VoidCallback? onViewerReady;

  @override
  ConsumerState<PdfReaderPdfView> createState() => _PdfReaderPdfViewState();
}

class _PdfReaderPdfViewState extends ConsumerState<PdfReaderPdfView> {
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
  PdfReaderViewerHandle? _readyNotifiedForHandle;

  @override
  void initState() {
    super.initState();
    _attachLoadingStateListener(widget.handle);
    if (widget.requiresReattach) {
      _scheduleReattachIfCached();
    }
    _notifyReadyIfNeeded();
  }

  @override
  void didUpdateWidget(covariant PdfReaderPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.handle, widget.handle)) {
      _detachLoadingStateListener();
      _reattachGuard.complete();
      _readyNotifiedForHandle = null;
      _attachLoadingStateListener(widget.handle);
      if (widget.requiresReattach) {
        _scheduleReattachIfCached();
      }
      _notifyReadyIfNeeded();
    } else if (oldWidget.requiresReattach != widget.requiresReattach &&
        widget.requiresReattach) {
      _scheduleReattachIfCached();
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
        _notifyReadyIfNeeded();
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

  /// Notifica [PdfReaderPdfView.onViewerReady] uma única vez por [handle],
  /// pós-frame — cobre tanto a transição ao vivo (listener acima) quanto o
  /// caso de um handle já pronto ao montar (reattach do cache LRU).
  void _notifyReadyIfNeeded() {
    final handle = widget.handle;
    if (identical(_readyNotifiedForHandle, handle)) return;
    if (handle.loadingState.value != PdfReaderLoadingState.success) return;

    _readyNotifiedForHandle = handle;
    final callback = widget.onViewerReady;
    if (callback == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!identical(widget.handle, handle)) return;
      callback();
    });
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

  void _handleVisiblePageChanged(int? pageNumber) {
    if (pageNumber == null) return;
    widget.handle.onPageChanged(pageNumber);
    widget.onPageChanged?.call(pageNumber);
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
      // Só navega. Reaplicar o fit aqui (comportamento antigo) produzia dois
      // saltos por virada e, na última página, o `goTo` do fit era clampado
      // contra a borda do documento e deixava a viewport no rodapé
      // (auditoria P3/P6). O fit é aplicado na abertura e no toggle de
      // fullscreen, pela tela.
      await widget.navigateToPage(targetPage);
    } finally {
      if (mounted) {
        setState(() => _pageTurnInProgress = false);
      }
    }
  }

  Widget _buildPdfContent() {
    final handle = widget.handle;
    // Important 1 (onda 4): spread some enquanto o fit efetivo é
    // `pageWidth` — ver doc de [pdfReaderEffectiveSpreadEnabledProvider].
    final spreadActive = ref.watch(pdfReaderEffectiveSpreadEnabledProvider);
    final isWeb = ref.watch(platformCapabilitiesProvider).isWeb;

    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasWidth = constraints.maxWidth;
        final viewportAspect = constraints.maxHeight > 0
            ? constraints.maxWidth / constraints.maxHeight
            : 0.0;

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
                params: buildPdfReaderViewerParams(
                  isWeb: isWeb,
                  scrollPhysics: PdfViewerParams.getScrollPhysics(context),
                  onViewerReady: (_, _) => handle.markViewerReady(),
                  onPageChanged: _handleVisiblePageChanged,
                  layoutPages: spreadActive
                      ? (pages, params) => spreadPageLayout(
                          pages,
                          params,
                          viewportAspect: viewportAspect,
                          fallback: defaultPdfPageLayout,
                        )
                      : null,
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
