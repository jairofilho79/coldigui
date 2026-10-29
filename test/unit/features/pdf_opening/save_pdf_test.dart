import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/save_pdf_platform.dart';
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
  Future<Uint8List> fetchBytes(
    String filePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    fetchCalled = true;
    return _bytes;
  }
}

class _FakeSavePlatform implements SavePdfPlatform {
  _FakeSavePlatform(this._docsDir);

  final Directory _docsDir;

  @override
  Future<String> savePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final targetDir = Directory('${_docsDir.path}/${SavePdf.savedPdfsSubdir}');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final targetFile = File('${targetDir.path}/$fileName');
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.path;
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
        _FakeSavePlatform(docsDir),
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

    test('path local usa fetchBytes e grava via platform', () async {
      final bytes = Uint8List.fromList([37, 80, 68, 70]);
      final cacheDir = await Directory.systemTemp.createTemp('save_local');
      final cacheFile = File('${cacheDir.path}/cached.pdf');
      await cacheFile.writeAsBytes(bytes);

      final datasource = _FakeBytesDatasource(bytes);
      final useCase = SavePdf(
        datasource,
        const OpenPdfDocument(),
        _FakeSavePlatform(docsDir),
      );

      final savedPath = await useCase.call(
        filePath: cacheFile.path,
        fileName: '001.pdf',
      );

      expect(datasource.fetchCalled, isTrue);
      expect(savedPath, contains('saved_pdfs'));
      expect(await File(savedPath).readAsBytes(), bytes);

      await cacheDir.delete(recursive: true);
    });
  });
}
