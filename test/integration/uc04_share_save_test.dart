import 'dart:io';

import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_opening/domain/usecases/save_pdf.dart';
import 'package:coldigui/features/pdf_opening/domain/usecases/share_pdf.dart';
import 'package:coldigui/features/pdf_opening/domain/utils/louvor_pdf_path.dart';
import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/open_pdf_document.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _FakeBundle extends AssetBundle {
  _FakeBundle(this._bytes);

  final Uint8List _bytes;

  @override
  Future<ByteData> load(String key) async {
    return _bytes.buffer.asByteData();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const openPdf = OpenPdfDocument();
  const resolver = PdfSourceResolver(apiBaseUrl: 'https://example.com');

  test('UC-04 — pipeline LouvorPdfPath + validação + resolução remota', () {
    final louvor = Louvor.fromManifest(
      nome: 'Teste',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '001.pdf',
      pdfId: 'YXNzZXRzL0NvbEFkdWx0b3MvMDAxLnBkZg',
    );

    final filePath = LouvorPdfPath.fromLouvor(louvor);
    expect(filePath, '/assets/ColAdultos/001.pdf');

    expect(() => openPdf.validateFilePath(filePath), returnsNormally);

    final source = resolver.resolve(filePath);
    expect(source.kind, PdfSourceKind.remoteUrl);
    expect(source.value, 'https://example.com/assets/ColAdultos/001.pdf');
  });

  test('UC-04 — SharePdf e SavePdf usam bytes do datasource asset', () async {
    final bytes = Uint8List.fromList([37, 80, 68, 70]);
    final datasource = PdfBytesDatasource(
      _FakeDio(Uint8List(0)),
      resolver: resolver,
      bundle: _FakeBundle(bytes),
    );

    var shared = false;
    final sharePdf = SharePdf(
      datasource,
      openPdf,
      getTemporaryDirectory: () async => Directory.systemTemp,
      shareXFiles: (_, {subject, sharePositionOrigin}) async {
        shared = true;
      },
    );

    await sharePdf.call(filePath: 'asset:fixtures/sample.pdf');
    expect(shared, isTrue);

    final docsDir = await Directory.systemTemp.createTemp('uc04_save');
    final savePdf = SavePdf(
      datasource,
      openPdf,
      getApplicationDocumentsDirectory: () async => docsDir,
    );

    final savedPath = await savePdf.call(
      filePath: 'asset:fixtures/sample.pdf',
      fileName: 'sample.pdf',
    );

    expect(savedPath, contains('saved_pdfs'));
    await docsDir.delete(recursive: true);
  });
}
