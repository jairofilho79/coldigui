import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/pdf_reader_viewer_handle.dart';
import 'pdf_reader_document_provider.dart';

/// Página exibida no indicador `page/total` da barra 3 (UC-11).
///
/// Durante [PdfReaderDisplayedPageNotifier.animateToPage], ignora atualizações
/// intermediárias de [PdfReaderViewerHandle.pageListenable] e só reflete o destino
/// ao concluir a animação. Scroll manual continua atualizando em tempo real.
final pdfReaderDisplayedPageProvider = NotifierProvider.autoDispose
    .family<PdfReaderDisplayedPageNotifier, int, String>(
      PdfReaderDisplayedPageNotifier.new,
    );

/// Estado da página mostrada ao usuário no leitor PDF.
class PdfReaderDisplayedPageNotifier extends Notifier<int> {
  PdfReaderDisplayedPageNotifier(this.filePath);

  final String filePath;

  PdfReaderViewerHandle? _handle;
  VoidCallback? _pageListener;
  VoidCallback? _loadingStateListener;
  var _suppressLiveUpdates = false;
  var _animating = false;

  @override
  int build() {
    ref.onDispose(_detach);

    ref.listen(pdfReaderSessionProvider(filePath), (_, next) {
      next.whenData(_attachToSession);
    }, fireImmediately: true);

    final sessionAsync = ref.read(pdfReaderSessionProvider(filePath));
    return sessionAsync.when(
      data: (session) {
        _attachToSession(session);
        if (session.handle.isViewerReady) {
          return session.handle.page;
        }
        return 1;
      },
      loading: () => 1,
      error: (_, _) => 1,
    );
  }

  PdfReaderLoadingState get loadingState =>
      _handle?.loadingState.value ?? PdfReaderLoadingState.loading;

  int? get pagesCount => _handle?.pagesCount;

  /// Navega com animação sem atualizar o indicador até o fim do movimento.
  Future<void> animateToPage({
    required int pageNumber,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
  }) async {
    final handle = _handle;
    if (handle == null) return;
    if (!handle.isViewerReady) return;

    final pagesCount = handle.pagesCount;
    if (pagesCount == null || pageNumber < 1 || pageNumber > pagesCount) {
      return;
    }
    if (_animating) return;

    _animating = true;
    _suppressLiveUpdates = true;
    try {
      await handle
          .animateToPage(pageNumber: pageNumber, duration: duration)
          .timeout(duration + const Duration(seconds: 2));
      state = pageNumber;
    } on TimeoutException {
      _syncStateFromHandle();
    } finally {
      _suppressLiveUpdates = false;
      _animating = false;
      _syncStateFromHandle();
    }
  }

  void _syncStateFromHandle() {
    final handle = _handle;
    if (handle == null || !handle.isViewerReady) return;
    state = handle.page;
  }

  void _attachToSession(PdfReaderSession session) {
    if (identical(_handle, session.handle) && _pageListener != null) return;
    _detach();

    _handle = session.handle;
    _pageListener = () {
      if (_suppressLiveUpdates || _handle == null) return;
      state = _handle!.page;
    };
    _handle!.pageListenable.addListener(_pageListener!);

    _loadingStateListener = () {
      final handle = _handle;
      if (handle == null ||
          handle.loadingState.value != PdfReaderLoadingState.success) {
        return;
      }
      if (!_suppressLiveUpdates) {
        state = handle.page;
      }
    };
    _handle!.loadingState.addListener(_loadingStateListener!);

    if (!_suppressLiveUpdates && !_animating && session.handle.isViewerReady) {
      state = session.handle.page;
    }
  }

  void _detach() {
    final handle = _handle;
    final pageListener = _pageListener;
    final loadingStateListener = _loadingStateListener;
    if (handle != null && pageListener != null) {
      handle.pageListenable.removeListener(pageListener);
    }
    if (handle != null && loadingStateListener != null) {
      handle.loadingState.removeListener(loadingStateListener);
    }
    _handle = null;
    _pageListener = null;
    _loadingStateListener = null;
  }
}
