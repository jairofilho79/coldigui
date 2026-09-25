import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/pdf_reader_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_reader_test_helpers.dart';

/// Controller que grava cada passo de navegação sem um `PdfViewer` anexado.
///
/// As matrizes de ajuste levam a página no `y` da translação e o modo no `x`
/// (1 = largura, 2 = altura) — só para os asserts saberem qual foi pedida.
class _RecordingController extends PdfViewerController {
  final List<String> steps = [];
  int? currentPage;

  @override
  bool get isReady => true;

  @override
  int? get pageNumber => currentPage;

  @override
  Future<void> goToPage({
    required int pageNumber,
    PdfPageAnchor? anchor,
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    steps.add('goToPage($pageNumber, ${duration.inMilliseconds})');
    currentPage = pageNumber;
  }

  @override
  Future<void> goTo(
    Matrix4? destination, {
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    final t = destination!.getTranslation();
    final mode = t.x == 1 ? 'largura' : 'altura';
    steps.add('goTo($mode ${t.y.toInt()}, ${duration.inMilliseconds})');
    currentPage = t.y.toInt();
  }

  @override
  Matrix4? calcMatrixFitWidthForPage({required int pageNumber}) =>
      Matrix4.translationValues(1, pageNumber.toDouble(), 0);

  @override
  Matrix4? calcMatrixFitHeightForPage({required int pageNumber}) =>
      Matrix4.translationValues(2, pageNumber.toDouble(), 0);
}

PdfReaderViewerHandle _handleAt(
  _RecordingController controller, {
  required int page,
  int pageCount = 16,
}) {
  final document = FakePdfDocument(pageCount: pageCount);
  final handle = PdfReaderViewerHandle(
    document: document,
    documentRef: PdfDocumentRefDirect(document, autoDispose: false),
    viewerController: controller,
  );
  controller.currentPage = page;
  handle.markViewerReady(pageNumber: page);
  return handle;
}

void main() {
  late _RecordingController controller;

  setUp(() => controller = _RecordingController());

  group('PdfReaderViewerHandle.animateToPage', () {
    test('página vizinha anima direto, com a duração de sempre', () async {
      final handle = _handleAt(controller, page: 5);
      await handle.animateToPage(pageNumber: 6);
      expect(controller.steps, ['goToPage(6, 500)']);
      expect(handle.page, 6);
    });

    test('página vizinha respeita a duração pedida', () async {
      final handle = _handleAt(controller, page: 5);
      await handle.animateToPage(
        pageNumber: 4,
        duration: const Duration(milliseconds: 300),
      );
      expect(controller.steps, ['goToPage(4, 300)']);
    });

    test('subindo de longe salta para a vizinha de baixo e anima só o '
        'último trecho', () async {
      final handle = _handleAt(controller, page: 16);
      await handle.animateToPage(pageNumber: 1);
      expect(controller.steps, ['goToPage(2, 0)', 'goToPage(1, 350)']);
      expect(handle.page, 1);
    });

    test('descendo de longe salta para a vizinha de cima', () async {
      final handle = _handleAt(controller, page: 1);
      await handle.animateToPage(pageNumber: 16);
      expect(controller.steps, ['goToPage(15, 0)', 'goToPage(16, 350)']);
      expect(handle.page, 16);
    });
  });

  group('PdfReaderViewerHandle.goToFirstPage', () {
    test('na primeira página não navega', () async {
      final handle = _handleAt(controller, page: 1);
      await handle.goToFirstPage(fitMode: PdfFitMode.pageFit);
      expect(controller.steps, isEmpty);
    });

    test('sem ajuste usa o mesmo salto curto do goToPage', () async {
      final handle = _handleAt(controller, page: 16);
      await handle.goToFirstPage();
      expect(controller.steps, ['goToPage(2, 0)', 'goToPage(1, 350)']);
    });

    test('da página 2, sem ajuste, anima 500 ms (fórmula antiga)', () async {
      final handle = _handleAt(controller, page: 2);
      await handle.goToFirstPage();
      expect(controller.steps, ['goToPage(1, 500)']);
    });

    test('com ajuste, salto e trecho final já chegam enquadrados', () async {
      final handle = _handleAt(controller, page: 16);
      await handle.goToFirstPage(fitMode: PdfFitMode.pageFit);
      expect(controller.steps, ['goTo(altura 2, 0)', 'goTo(altura 1, 350)']);
      expect(handle.page, 1);
    });

    test('com ajuste pela largura, da página 2, um movimento só', () async {
      final handle = _handleAt(controller, page: 2);
      await handle.goToFirstPage(fitMode: PdfFitMode.pageWidth);
      expect(controller.steps, ['goTo(largura 1, 500)']);
    });
  });
}
