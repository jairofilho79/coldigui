import 'dart:async';

import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_displayed_page_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_reader_test_helpers.dart';

class _ControllableHandle extends TrackablePdfReaderViewerHandle {
  _ControllableHandle({
    required FakePdfDocument document,
    required super.viewerController,
  }) : super(
         document: document,
         documentRef: PdfDocumentRefDirect(document, autoDispose: false),
       );

  Completer<void>? animateCompleter;

  @override
  bool get isViewerReady =>
      !wasDisposed && loadingState.value == PdfReaderLoadingState.success;

  @override
  Future<void> animateToPage({
    required int pageNumber,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
  }) async {
    animateCompleter = Completer<void>();
    await animateCompleter!.future;
    pageListenable.value = pageNumber;
  }

  void completeAnimation() {
    animateCompleter?.complete();
    animateCompleter = null;
  }
}

PdfReaderSession _sessionFor(_ControllableHandle handle) {
  return PdfReaderSession(
    handle: handle,
    filePath: 'asset:fixtures/sample.pdf',
  );
}

void main() {
  test('animateToPage congela indicador e sincroniza ao concluir', () async {
    final handle = _ControllableHandle(
      document: FakePdfDocument(pageCount: 5),
      viewerController: PdfViewerController(),
    );
    handle.loadingState.value = PdfReaderLoadingState.success;
    handle.pageListenable.value = 4;

    final container = ProviderContainer(
      overrides: [
        pdfReaderSessionProvider(
          'asset:fixtures/sample.pdf',
        ).overrideWith((ref) async => _sessionFor(handle)),
      ],
    );
    addTearDown(container.dispose);

    final sessionProvider = pdfReaderSessionProvider(
      'asset:fixtures/sample.pdf',
    );
    container.listen(sessionProvider, (_, _) {});
    await container.read(sessionProvider.future);

    final provider = pdfReaderDisplayedPageProvider(
      'asset:fixtures/sample.pdf',
    );
    container.listen(provider, (_, _) {});
    expect(container.read(provider), 4);

    final notifier = container.read(provider.notifier);
    final animation = notifier.animateToPage(pageNumber: 1);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider), 4);

    handle.pageListenable.value = 2;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider), 4);

    handle.completeAnimation();
    await animation;
    expect(container.read(provider), 1);
  });

  test(
    'animateToPage restaura sync após animação pendente (timeout)',
    () async {
      final handle = _ControllableHandle(
        document: FakePdfDocument(pageCount: 5),
        viewerController: PdfViewerController(),
      );
      handle.loadingState.value = PdfReaderLoadingState.success;
      handle.pageListenable.value = 3;

      final container = ProviderContainer(
        overrides: [
          pdfReaderSessionProvider(
            'asset:fixtures/sample.pdf',
          ).overrideWith((ref) async => _sessionFor(handle)),
        ],
      );
      addTearDown(container.dispose);

      final sessionProvider = pdfReaderSessionProvider(
        'asset:fixtures/sample.pdf',
      );
      container.listen(sessionProvider, (_, _) {});
      await container.read(sessionProvider.future);

      final provider = pdfReaderDisplayedPageProvider(
        'asset:fixtures/sample.pdf',
      );
      container.listen(provider, (_, _) {});

      final notifier = container.read(provider.notifier);

      final animation = notifier.animateToPage(
        pageNumber: 1,
        duration: const Duration(milliseconds: 50),
      );
      await Future<void>.delayed(Duration.zero);

      handle.pageListenable.value = 2;
      await animation;

      expect(container.read(provider), 2);

      handle.pageListenable.value = 5;
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider), 5);
    },
  );

  test('pageListenable atualiza indicador após animateToPage', () async {
    final handle = _ControllableHandle(
      document: FakePdfDocument(pageCount: 3),
      viewerController: PdfViewerController(),
    );
    handle.loadingState.value = PdfReaderLoadingState.success;
    handle.pageListenable.value = 2;

    final container = ProviderContainer(
      overrides: [
        pdfReaderSessionProvider(
          'asset:fixtures/sample.pdf',
        ).overrideWith((ref) async => _sessionFor(handle)),
      ],
    );
    addTearDown(container.dispose);

    final sessionProvider = pdfReaderSessionProvider(
      'asset:fixtures/sample.pdf',
    );
    container.listen(sessionProvider, (_, _) {});
    await container.read(sessionProvider.future);

    final provider = pdfReaderDisplayedPageProvider(
      'asset:fixtures/sample.pdf',
    );
    container.listen(provider, (_, _) {});
    final notifier = container.read(provider.notifier);

    final animation = notifier.animateToPage(pageNumber: 1);
    await Future<void>.delayed(Duration.zero);
    handle.completeAnimation();
    await animation;

    handle.pageListenable.value = 3;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider), 3);
  });
}
