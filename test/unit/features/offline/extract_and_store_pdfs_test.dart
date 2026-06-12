import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/datasources/zip_package_downloader.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/usecases/extract_and_store_pdfs.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'offline_test_helpers.dart';

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late PdfLocalStore store;
  late OfflinePdfRepositoryImpl repository;
  late ExtractAndStorePdfs useCase;

  final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);

  late String pdfId1;
  late String pdfId2;
  late String pdfId3;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    pdfId1 = encodePdfId('ColAdultos/001.pdf');
    pdfId2 = encodePdfId('ColAdultos/002.pdf');
    pdfId3 = encodePdfId('ColAdultos/003.pdf');
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('extract_store_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = await openOfflineTestIsar(tempDir);
    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: store,
      local: OfflinePdfLocalDatasource(isar),
    );
    useCase = ExtractAndStorePdfs(
      repository,
      store,
      ZipPackageDownloader(Dio(), store),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('extrai ZIP e indexa PDFs no Isar', () async {
    final zipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/001.pdf': pdfBytes,
        'ColAdultos/002.pdf': pdfBytes,
        'ColAdultos/003.pdf': pdfBytes,
      },
    );

    final result = await useCase(
      zipPath: zipPath,
      expectedPdfIds: [pdfId1, pdfId2, pdfId3],
      materialCategory: 'Partitura',
    );

    expect(result.storedCount, 3);
    expect(await File(zipPath).exists(), isFalse);

    for (final pdfId in [pdfId1, pdfId2, pdfId3]) {
      final entry = await repository.lookup(pdfId);
      expect(entry, isNotNull);
    }
  });

  test('pula PDF já cacheado', () async {
    await repository.upsert(
      pdfId: pdfId1,
      bytes: pdfBytes,
      category: 'ColAdultos',
    );

    final zipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/001.pdf': pdfBytes,
        'ColAdultos/002.pdf': pdfBytes,
      },
    );

    final result = await useCase(
      zipPath: zipPath,
      expectedPdfIds: [pdfId1, pdfId2],
      materialCategory: 'Partitura',
    );

    expect(result.storedCount, 1);
    expect(result.skippedCount, 1);
  });
}
