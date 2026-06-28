import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import 'pdf_reader_document_provider.dart';

/// Página exibida no indicador `page/total` da barra 3 (UC-11).
///
/// Durante [PdfReaderDisplayedPageNotifier.animateToPage], ignora atualizações
/// intermediárias de [PdfControllerPinch.pageListenable] e só reflete o destino
/// ao concluir a animação. Scroll manual continua atualizando em tempo real.
///
/// Escuta também [PdfControllerPinch.loadingState] para sincronizar a página
/// assim que o PDF termina de carregar no [PdfViewPinch].
final pdfReaderDisplayedPageProvider = NotifierProvider.autoDispose
    .family<PdfReaderDisplayedPageNotifier, int, String>(
  PdfReaderDisplayedPageNotifier.new,
);

/// Estado da página mostrada ao usuário no leitor PDF.
class PdfReaderDisplayedPageNotifier
    extends AutoDisposeFamilyNotifier<int, String> {
  PdfControllerPinch? _controller;
  VoidCallback? _pageListener;
  VoidCallback? _loadingStateListener;
  var _suppressLiveUpdates = false;
  var _animating = false;

  @override
  int build(String filePath) {
    ref.listen(pdfReaderSessionProvider(filePath), (_, next) {
      next.whenData(_attachToSession);
    });

    ref.watch(pdfReaderSessionProvider(filePath)).whenData(_attachToSession);

    ref.onDispose(_detach);

    final session = ref.watch(pdfReaderSessionProvider(filePath)).valueOrNull;
    if (session != null &&
        session.controller.loadingState.value == PdfLoadingState.success) {
      return session.controller.page;
    }
    return 1;
  }

  PdfLoadingState get loadingState =>
      _controller?.loadingState.value ?? PdfLoadingState.loading;

  int? get pagesCount => _controller?.pagesCount;

  /// Navega com animação sem atualizar o indicador até o fim do movimento.
  Future<void> animateToPage({
    required int pageNumber,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
  }) async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.loadingState.value != PdfLoadingState.success) return;

    final pagesCount = controller.pagesCount;
    if (pagesCount == null || pageNumber < 1 || pageNumber > pagesCount) {
      return;
    }
    if (_animating) return;

    _animating = true;
    _suppressLiveUpdates = true;
    try {
      await controller.animateToPage(
        pageNumber: pageNumber,
        duration: duration,
        curve: curve,
      );
      state = pageNumber;
    } finally {
      _suppressLiveUpdates = false;
      _animating = false;
    }
  }

  void _attachToSession(PdfReaderSession session) {
    if (identical(_controller, session.controller)) return;
    _detach();

    _controller = session.controller;
    _pageListener = () {
      if (_suppressLiveUpdates || _controller == null) return;
      state = _controller!.page;
    };
    _controller!.pageListenable.addListener(_pageListener!);

    _loadingStateListener = () {
      final controller = _controller;
      if (controller == null ||
          controller.loadingState.value != PdfLoadingState.success) {
        return;
      }
      if (!_suppressLiveUpdates) {
        state = controller.page;
      }
    };
    _controller!.loadingState.addListener(_loadingStateListener!);
  }

  void _detach() {
    final controller = _controller;
    final pageListener = _pageListener;
    final loadingStateListener = _loadingStateListener;
    if (controller != null && pageListener != null) {
      controller.pageListenable.removeListener(pageListener);
    }
    if (controller != null && loadingStateListener != null) {
      controller.loadingState.removeListener(loadingStateListener);
    }
    _controller = null;
    _pageListener = null;
    _loadingStateListener = null;
  }
}
