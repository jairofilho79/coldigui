import 'dart:async';
import 'dart:typed_data';

import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/data/adapters/pdfx_viewer_adapter.dart';
import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/pdf_reader_preferences.dart';
import 'package:dio/dio.dart';
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
}
