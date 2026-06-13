import 'dart:async';

import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/data/adapters/pdfx_viewer_adapter.dart';
import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/pdf_reader_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfx/pdfx.dart';

class _FakeDio implements Dio {
  _FakeDio(this._bytes);

  final Uint8List _bytes;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return Response<T>(
      data: _bytes as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PdfBytesDatasource _datasource(Uint8List bytes) {
  return PdfBytesDatasource(
    _FakeDio(bytes),
    resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
  );
}

class _FitModeTestController extends PdfControllerPinch {
  _FitModeTestController({
    required this.pageRect,
    required this.viewRectValue,
    this.calculatePageFitMatrixImpl,
  }) : super(document: Completer<PdfDocument>().future) {
    loadingState.value = PdfLoadingState.success;
  }

  final Rect? pageRect;
  final Rect viewRectValue;
  final Matrix4? Function({required int pageNumber, double? padding})?
      calculatePageFitMatrixImpl;
  void Function(Matrix4? destination)? onGoTo;

  @override
  int get page => 1;

  @override
  Rect? getPageRect(int pageNumber) => pageRect;

  @override
  Rect get viewRect => viewRectValue;

  @override
  Matrix4? calculatePageFitMatrix({required int pageNumber, double? padding}) {
    return calculatePageFitMatrixImpl?.call(
          pageNumber: pageNumber,
          padding: padding,
        ) ??
        Matrix4.identity();
  }

  @override
  Future<void> goTo({
    Matrix4? destination,
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeInOut,
  }) async {
    onGoTo?.call(destination);
  }
}

PdfxViewerAdapter _adapter() {
  return PdfxViewerAdapter(
    _datasource(Uint8List(0)),
    resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PdfxViewerAdapter dispose limpa controller inativo', () async {
    final adapter = PdfxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );

    await adapter.dispose();
    expect(adapter.controller, isNull);
  });

  test('getters seguros retornam null sem controller', () {
    final adapter = PdfxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );

    expect(adapter.currentPage, isNull);
    expect(adapter.pagesCount, isNull);
  });

  test('navegação não lança sem controller ativo', () async {
    final adapter = PdfxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );

    await expectLater(adapter.goToPage(1), completes);
    await expectLater(adapter.nextPage(), completes);
    await expectLater(adapter.previousPage(), completes);
    await expectLater(adapter.applyFitMode(PdfFitMode.pageFit), completes);
  });

  test('bindController e unbindController ligam sessão ativa', () {
    final adapter = PdfxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );
    final controller = PdfControllerPinch(
      document: Completer<PdfDocument>().future,
    );
    addTearDown(controller.dispose);

    adapter.bindController(controller);
    expect(adapter.controller, same(controller));

    adapter.unbindController(controller);
    expect(adapter.controller, isNull);
  });

  test('unbindController ignora controller que não é o ativo', () {
    final adapter = PdfxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );
    final active = PdfControllerPinch(
      document: Completer<PdfDocument>().future,
    );
    final other = PdfControllerPinch(
      document: Completer<PdfDocument>().future,
    );
    addTearDown(active.dispose);
    addTearDown(other.dispose);

    adapter.bindController(active);
    adapter.unbindController(other);

    expect(adapter.controller, same(active));
  });

  test('openDocument não dispose controller anterior', () async {
    final adapter = PdfxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );
    final previous = PdfControllerPinch(
      document: Completer<PdfDocument>().future,
    );
    addTearDown(previous.dispose);

    adapter.bindController(previous);
    final created = await adapter.openDocument('asset:fixtures/sample.pdf');

    expect(created, isNot(same(previous)));
    expect(adapter.controller, same(previous));
    addTearDown(created.dispose);
  });

  test('applyFitMode pageFit ignora pageRect nulo sem chamar goTo', () async {
    final adapter = _adapter();
    final controller = _FitModeTestController(
      pageRect: null,
      viewRectValue: const Rect.fromLTWH(0, 0, 400, 800),
    );
    addTearDown(controller.dispose);

    var goToCalls = 0;
    controller.onGoTo = (_) => goToCalls++;

    adapter.bindController(controller);
    await expectLater(adapter.applyFitMode(PdfFitMode.pageFit), completes);

    expect(goToCalls, 0);
  });

  test('applyFitMode pageFit ignora altura zero sem chamar goTo', () async {
    final adapter = _adapter();
    final controller = _FitModeTestController(
      pageRect: const Rect.fromLTWH(0, 0, 100, 0),
      viewRectValue: const Rect.fromLTWH(0, 0, 400, 800),
    );
    addTearDown(controller.dispose);

    var goToCalls = 0;
    controller.onGoTo = (_) => goToCalls++;

    adapter.bindController(controller);
    await expectLater(adapter.applyFitMode(PdfFitMode.pageFit), completes);

    expect(goToCalls, 0);
  });

  test('applyFitMode registra erros inesperados sem propagar', () async {
    final adapter = _adapter();
    final controller = _FitModeTestController(
      pageRect: const Rect.fromLTWH(0, 0, 100, 200),
      viewRectValue: const Rect.fromLTWH(0, 0, 400, 800),
      calculatePageFitMatrixImpl: ({required int pageNumber, double? padding}) {
        throw StateError('unexpected fit failure');
      },
    );
    addTearDown(controller.dispose);

    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message ?? '');
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    adapter.bindController(controller);
    await expectLater(adapter.applyFitMode(PdfFitMode.pageWidth), completes);

    expect(
      logs.any((line) => line.contains('[PdfxViewerAdapter.applyFitMode]')),
      isTrue,
    );
    expect(
      logs.any((line) => line.contains('unexpected fit failure')),
      isTrue,
    );
  });
}
