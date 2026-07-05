import 'dart:typed_data';
import 'dart:ui';

import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_opening/domain/usecases/share_pdf.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/open_pdf_document.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

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
  }) async {
    fetchCalled = true;
    return _bytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharePdf', () {
    XFile? sharedFile;
    String? sharedSubject;

    setUp(() {
      sharedFile = null;
      sharedSubject = null;
    });

    SharePdf buildUseCase({required Uint8List bytes}) {
      return SharePdf(
        _FakeBytesDatasource(bytes),
        const OpenPdfDocument(),
        shareXFiles: (files, {subject, sharePositionOrigin}) async {
          sharedFile = files.first;
          sharedSubject = subject;
        },
      );
    }

    test('rejeita path inválido antes do fetch', () async {
      final useCase = buildUseCase(bytes: Uint8List.fromList([1]));

      await expectLater(
        useCase.call(filePath: 'file:///etc/passwd'),
        throwsA(isA<InvalidPdfPathException>()),
      );
      expect(sharedFile, isNull);
    });

    test('compartilha bytes via XFile.fromData', () async {
      final bytes = Uint8List.fromList([37, 80, 68, 70]);
      final useCase = buildUseCase(bytes: bytes);

      await useCase.call(
        filePath: 'asset:fixtures/sample.pdf',
        displayName: 'Louvor Teste',
      );

      expect(sharedFile, isNotNull);
      expect(sharedSubject, 'Louvor Teste');
      expect(await sharedFile!.readAsBytes(), bytes);
      expect(sharedFile!.mimeType, 'application/pdf');
    });

    test('repassa sharePositionOrigin para shareXFiles', () async {
      final bytes = Uint8List.fromList([37, 80, 68, 70]);
      Rect? capturedOrigin;
      final useCase = SharePdf(
        _FakeBytesDatasource(bytes),
        const OpenPdfDocument(),
        shareXFiles: (files, {subject, sharePositionOrigin}) async {
          capturedOrigin = sharePositionOrigin;
        },
      );

      final origin = Rect.fromLTWH(10, 20, 48, 48);
      await useCase.call(
        filePath: 'asset:fixtures/sample.pdf',
        sharePositionOrigin: origin,
      );

      expect(capturedOrigin, origin);
    });

    test('path local usa fetchBytes e XFile.fromData', () async {
      final bytes = Uint8List.fromList([37, 80, 68, 70]);
      const localPath = '/var/mobile/plpcg_pdfs/cached.pdf';

      final datasource = _FakeBytesDatasource(bytes);
      final useCase = SharePdf(
        datasource,
        const OpenPdfDocument(),
        shareXFiles: (files, {subject, sharePositionOrigin}) async {
          sharedFile = files.first;
          sharedSubject = subject;
        },
      );

      await useCase.call(filePath: localPath, displayName: 'Louvor Cache');

      expect(datasource.fetchCalled, isTrue);
      expect(sharedFile, isNotNull);
      expect(await sharedFile!.readAsBytes(), bytes);
      expect(sharedSubject, 'Louvor Cache');
    });
  });
}
