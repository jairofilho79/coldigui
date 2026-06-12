import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_opening/domain/usecases/save_pdf.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/open_pdf_document.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubDio implements Dio {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeBytesDatasource extends PdfBytesDatasource {
  _FakeBytesDatasource(this._bytes) : super(_StubDio());

  final Uint8List _bytes;
  var fetchCalled = false;

  @override
  Future<Uint8List> fetchBytes(String filePath) async {
    fetchCalled = true;
    return _bytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavePdf', () {
    late Directory docsDir;

    setUp(() async {
      docsDir = await Directory.systemTemp.createTemp('save_pdf_test');
    });

    tearDown(() async {
      if (await docsDir.exists()) {
        await docsDir.delete(recursive: true);
      }
    });

    SavePdf buildUseCase({required Uint8List bytes}) {
      return SavePdf(
        _FakeBytesDatasource(bytes),
        const OpenPdfDocument(),
        getApplicationDocumentsDirectory: () async => docsDir,
      );
    }

    test('rejeita path inválido', () async {
      final useCase = buildUseCase(bytes: Uint8List.fromList([1]));

      await expectLater(
        useCase.call(filePath: '../secret.pdf'),
        throwsA(isA<InvalidPdfPathException>()),
      );
    });

    test('grava PDF com nome sanitizado em saved_pdfs/', () async {
      final bytes = Uint8List.fromList([37, 80, 68, 70]);
      final useCase = buildUseCase(bytes: bytes);

      final savedPath = await useCase.call(
        filePath: '/assets/ColAdultos/001.pdf',
        fileName: '../evil/001.pdf',
      );

      expect(savedPath, contains('saved_pdfs'));
      expect(savedPath, endsWith('001.pdf'));
      expect(await File(savedPath).readAsBytes(), bytes);
    });

    test('path local copia arquivo sem fetchBytes', () async {
      final bytes = Uint8List.fromList([37, 80, 68, 70]);
      final cacheDir = await Directory.systemTemp.createTemp('save_local');
      final cacheFile = File('${cacheDir.path}/cached.pdf');
      await cacheFile.writeAsBytes(bytes);

      final datasource = _FakeBytesDatasource(bytes);
      final useCase = SavePdf(
        datasource,
        const OpenPdfDocument(),
        getApplicationDocumentsDirectory: () async => docsDir,
      );

      final savedPath = await useCase.call(
        filePath: cacheFile.path,
        fileName: '001.pdf',
      );

      expect(datasource.fetchCalled, isFalse);
      expect(savedPath, contains('saved_pdfs'));
      expect(await File(savedPath).readAsBytes(), bytes);

      await cacheDir.delete(recursive: true);
    });
  });
}
