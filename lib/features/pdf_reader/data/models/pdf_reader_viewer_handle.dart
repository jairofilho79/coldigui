import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../domain/entities/pdf_reader_preferences.dart';
import '../../presentation/utils/pdf_page_jump_policy.dart';

/// Estado de carregamento do viewer — equivalente estável ao `PdfLoadingState` do pdfx.
enum PdfReaderLoadingState { loading, success }

/// Snapshot de viewport para políticas de gesto (swipe horizontal).
class PdfViewportSnapshot {
  const PdfViewportSnapshot({
    required this.pageRect,
    required this.viewWidth,
    required this.zoomRatio,
    required this.transform,
  });

  final Rect pageRect;
  final double viewWidth;
  final double zoomRatio;
  final Matrix4 transform;
}

/// Handle de sessão do viewer — oculta pdfrx da camada presentation (ADR-002 / Fase C).
class PdfReaderViewerHandle {
  PdfReaderViewerHandle({
    required this.document,
    required this.documentRef,
    required this.viewerController,
    this.initialPage = 1,
  }) {
    loadingState = ValueNotifier(PdfReaderLoadingState.loading);
    pageListenable = ValueNotifier(initialPage);
    viewerController.addListener(_onControllerChanged);
  }

  final PdfDocument document;
  final PdfDocumentRef documentRef;
  final PdfViewerController viewerController;
  final int initialPage;

  late final ValueNotifier<PdfReaderLoadingState> loadingState;
  late final ValueNotifier<int> pageListenable;

  var _disposed = false;

  /// Página atual (1-based).
  int get page => pageListenable.value;

  /// Total de páginas — disponível após abertura do documento.
  int? get pagesCount {
    if (_disposed) return null;
    final count = document.pages.length;
    return count > 0 ? count : null;
  }

  /// Viewer anexado ao widget e documento pronto para interação.
  bool get isViewerReady =>
      !_disposed &&
      viewerController.isReady &&
      loadingState.value == PdfReaderLoadingState.success;

  void markViewerReady({int? pageNumber}) {
    if (_disposed) return;
    loadingState.value = PdfReaderLoadingState.success;
    final page = pageNumber ?? viewerController.pageNumber ?? initialPage;
    if (pageListenable.value != page) {
      pageListenable.value = page;
    }
  }

  void onPageChanged(int? pageNumber) {
    if (_disposed || pageNumber == null) return;
    if (pageListenable.value != pageNumber) {
      pageListenable.value = pageNumber;
    }
  }

  /// Navega para [pageNumber] — virada vizinha anima direto por [duration];
  /// destino a mais de uma página faz o «salto curto» de
  /// [PdfPageJumpPolicy]: salto sem animação para a vizinha do destino e
  /// [PdfPageJumpPolicy.finalLegDuration] só no último trecho.
  Future<void> animateToPage({
    required int pageNumber,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
  }) => _navigateTo(
    pageNumber,
    duration: duration,
    step: (page, stepDuration) =>
        viewerController.goToPage(pageNumber: page, duration: stepDuration),
  );

  /// Volta à primeira página — long-press no indicador `page/total`.
  ///
  /// Mesmo «salto curto» de [animateToPage] (da 16 salta para a 2 e anima
  /// só até a 1). Com [fitMode], cada passo já enquadra a página nesse
  /// ajuste ([fitMatrixForPage]) em vez do enquadramento do `goToPage` —
  /// o reajuste do zoom (desfaz pinch) chega no mesmo movimento, sem um
  /// segundo `goTo` animado depois da chegada.
  Future<void> goToFirstPage({PdfFitMode? fitMode}) async {
    if (_disposed || !isViewerReady) return;
    if (pageListenable.value <= 1) return;
    if (fitMode == null) return animateToPage(pageNumber: 1);

    await _navigateTo(
      1,
      duration: const Duration(milliseconds: 500),
      step: (page, stepDuration) => viewerController.goTo(
        fitMatrixForPage(page, fitMode),
        duration: stepDuration,
      ),
    );
  }

  /// Matriz que enquadra [pageNumber] em [mode] — `pageWidth` pela largura,
  /// `pageFit` pela altura. Usada por [goToFirstPage] e pelo
  /// `PdfrxViewerAdapter.applyFitMode`.
  Matrix4? fitMatrixForPage(int pageNumber, PdfFitMode mode) => switch (mode) {
    PdfFitMode.pageWidth => viewerController.calcMatrixFitWidthForPage(
      pageNumber: pageNumber,
    ),
    PdfFitMode.pageFit => viewerController.calcMatrixFitHeightForPage(
      pageNumber: pageNumber,
    ),
  };

  /// Executa a navegação em até dois passos de [step]: o salto sem animação
  /// até a página de pouso ([PdfPageJumpPolicy.landingPage]), se houver, e
  /// a animação até [pageNumber] — por [duration] quando não há salto.
  Future<void> _navigateTo(
    int pageNumber, {
    required Duration duration,
    required Future<void> Function(int page, Duration duration) step,
  }) async {
    if (_disposed || !isViewerReady) return;
    final landing = PdfPageJumpPolicy.landingPage(
      from: page,
      to: pageNumber,
      pageCount: pagesCount ?? 0,
    );
    final legDuration = landing == null
        ? duration
        : PdfPageJumpPolicy.finalLegDuration;
    try {
      if (landing != null) {
        await step(landing, Duration.zero);
        if (_disposed) return;
      }
      await step(
        pageNumber,
        legDuration,
      ).timeout(legDuration + const Duration(seconds: 2));
    } on TimeoutException {
      // Animação interrompida — sincroniza com a página visível abaixo.
    }
    _syncPageFromController();
  }

  void _syncPageFromController() {
    final page = viewerController.pageNumber;
    if (page != null && pageListenable.value != page) {
      pageListenable.value = page;
    }
  }

  /// Reanexa viewer após reutilização do cache LRU (equivalente ao `loadDocument` do pdfx).
  Future<void> reattachIfNeeded() async {
    if (_disposed || !viewerController.isReady) return;
    viewerController.invalidate();
  }

  PdfViewportSnapshot? viewportSnapshot() {
    if (_disposed || !isViewerReady) return null;

    final controller = viewerController;
    final pageNumber = controller.pageNumber ?? page;
    if (pageNumber < 1 || pageNumber > controller.layout.pageLayouts.length) {
      return null;
    }

    return PdfViewportSnapshot(
      pageRect: controller.layout.pageLayouts[pageNumber - 1],
      viewWidth: controller.viewSize.width,
      zoomRatio: controller.currentZoom,
      transform: controller.value,
    );
  }

  void _onControllerChanged() {
    if (_disposed || !viewerController.isReady) return;
    loadingState.value = PdfReaderLoadingState.success;
    final page = viewerController.pageNumber;
    if (page != null && pageListenable.value != page) {
      pageListenable.value = page;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    viewerController.removeListener(_onControllerChanged);
    loadingState.dispose();
    pageListenable.dispose();
    unawaited(document.dispose());
  }
}
