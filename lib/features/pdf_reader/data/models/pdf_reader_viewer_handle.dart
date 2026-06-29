import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

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

  Future<void> animateToPage({
    required int pageNumber,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
  }) async {
    if (_disposed || !isViewerReady) return;
    await viewerController.goToPage(pageNumber: pageNumber, duration: duration);
    pageListenable.value = pageNumber;
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
