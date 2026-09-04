@TestOn('vm')
library;

import 'dart:io';

import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/datasources/zip_package_downloader.dart';
import 'package:coldigui/features/offline/data/utils/zip_extraction_runner_native.dart';
import 'package:coldigui/features/offline/data/utils/zip_pdf_extractor_types.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_test_helpers.dart';

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late PdfLocalStore store;
  late ZipPackageDownloader downloader;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zip_runner_native_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);
    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    downloader = ZipPackageDownloader(Dio(), pdfStoragePortFor(store));
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  File writeCorruptZip() {
    final file = File('${tempDir.path}/corrompido.zip');
    file.writeAsBytesSync(List<int>.filled(64, 0x41));
    return file;
  }

  test('ZIP corrompido é apagado e vira ZipCorruptedException', () async {
    final corrupt = writeCorruptZip();

    await expectLater(
      runZipExtraction(
        params: ZipExtractParams(
          zipPath: corrupt.path,
          rootPath: docsDir.path,
          expectedPdfIds: const ['abc'],
          skipPdfIds: const [],
        ),
        zipDownloader: downloader,
        store: pdfStoragePortFor(store),
      ),
      throwsA(
        isA<ZipCorruptedException>().having(
          (e) => e.path,
          'path',
          corrupt.path,
        ),
      ),
    );

    expect(await corrupt.exists(), isFalse);
  });

  test(
    'ZIP corrompido no caminho com progresso também vira ZipCorruptedException',
    () async {
      final corrupt = writeCorruptZip();

      await expectLater(
        runZipExtraction(
          params: ZipExtractParams(
            zipPath: corrupt.path,
            rootPath: docsDir.path,
            expectedPdfIds: const ['abc'],
            skipPdfIds: const [],
          ),
          zipDownloader: downloader,
          store: pdfStoragePortFor(store),
          onExtractProgress: (extracted, total) {},
        ),
        throwsA(isA<ZipCorruptedException>()),
      );

      expect(await corrupt.exists(), isFalse);
    },
  );

  test('ZIP válido extrai normalmente', () async {
    final zipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/010.pdf': const [0x25, 0x50, 0x44, 0x46, 0x2D],
      },
    );

    final result = await runZipExtraction(
      params: ZipExtractParams(
        zipPath: zipPath,
        rootPath: docsDir.path,
        expectedPdfIds: const [],
        skipPdfIds: const [],
      ),
      zipDownloader: downloader,
      store: pdfStoragePortFor(store),
    );

    expect(result.unmatchedEntries, isNotEmpty);
    expect(await File(zipPath).exists(), isTrue);
  });
}
