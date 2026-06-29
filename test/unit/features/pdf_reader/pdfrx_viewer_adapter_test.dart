import 'dart:async';

import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/data/adapters/pdfrx_viewer_adapter.dart';
import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/pdf_reader_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_reader_test_helpers.dart';

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

PdfrxViewerAdapter _adapter() {
  return PdfrxViewerAdapter(
    _datasource(Uint8List(0)),
    resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PdfrxViewerAdapter dispose limpa handle inativo', () async {
    final adapter = PdfrxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );

    await adapter.dispose();
    expect(adapter.activeHandle, isNull);
  });

  test('getters seguros retornam null sem handle', () {
    final adapter = PdfrxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );

    expect(adapter.currentPage, isNull);
    expect(adapter.pagesCount, isNull);
  });

  test('navegação não lança sem handle ativo', () async {
    final adapter = PdfrxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );

    await expectLater(adapter.goToPage(1), completes);
    await expectLater(adapter.nextPage(), completes);
    await expectLater(adapter.previousPage(), completes);
    await expectLater(adapter.applyFitMode(PdfFitMode.pageFit), completes);
  });

  test('bindHandle e unbindHandle ligam sessão ativa', () {
    final adapter = _adapter();
    final handle = createTrackableHandle();
    addTearDown(handle.dispose);

    adapter.bindHandle(handle);
    expect(adapter.activeHandle, same(handle));

    adapter.unbindHandle(handle);
    expect(adapter.activeHandle, isNull);
  });

  test('unbindHandle ignora handle que não é o ativo', () {
    final adapter = _adapter();
    final active = createTrackableHandle();
    final other = createTrackableHandle();
    addTearDown(active.dispose);
    addTearDown(other.dispose);

    adapter.bindHandle(active);
    adapter.unbindHandle(other);

    expect(adapter.activeHandle, same(active));
  });

  test('openDocument não dispose handle anterior', () async {
    final adapter = _OpenDocumentTestAdapter();
    final previous = createTrackableHandle();
    addTearDown(previous.dispose);

    adapter.bindHandle(previous);
    final created = await adapter.openDocument('asset:fixtures/sample.pdf');

    expect(created, isNot(same(previous)));
    expect(adapter.activeHandle, same(previous));
    addTearDown(created.dispose);
  });

  test('applyFitMode ignora handle sem viewer pronto', () async {
    final adapter = _adapter();
    final handle = createTrackableHandle();
    addTearDown(handle.dispose);

    adapter.bindHandle(handle);
    await expectLater(adapter.applyFitMode(PdfFitMode.pageFit), completes);
  });

  test('applyFitMode registra erros inesperados sem propagar', () async {
    final adapter = _FitModeThrowingAdapter();
    final handle = _FitModeThrowingHandle();
    addTearDown(handle.dispose);

    adapter.bindHandle(handle);
    handle.markViewerReady();

    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message ?? '');
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    await expectLater(adapter.applyFitMode(PdfFitMode.pageWidth), completes);

    expect(
      logs.any((line) => line.contains('[PdfrxViewerAdapter.applyFitMode]')),
      isTrue,
    );
  });
}

class _FitModeThrowingHandle extends PdfReaderViewerHandle {
  _FitModeThrowingHandle()
    : super(
        document: _sharedDoc,
        documentRef: PdfDocumentRefDirect(_sharedDoc, autoDispose: false),
        viewerController: _ThrowingViewerController(),
      );

  static final _sharedDoc = FakePdfDocument();

  @override
  bool get isViewerReady => true;
}

class _OpenDocumentTestAdapter extends PdfrxViewerAdapter {
  _OpenDocumentTestAdapter()
    : super(
        PdfBytesDatasource(
          _FakeDio(Uint8List(0)),
          resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
        ),
      );

  @override
  Future<PdfReaderViewerHandle> openDocument(String filePath) async {
    return createTrackableHandle();
  }
}

class _ThrowingViewerController extends PdfViewerController {
  @override
  bool get isReady => true;

  @override
  int? get pageNumber => 1;

  @override
  Matrix4? calcMatrixFitWidthForPage({required int pageNumber}) {
    throw StateError('unexpected fit failure');
  }
}

class _FitModeThrowingAdapter extends PdfrxViewerAdapter {
  _FitModeThrowingAdapter()
    : super(
        PdfBytesDatasource(
          _FakeDio(Uint8List(0)),
          resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
        ),
      );
}
