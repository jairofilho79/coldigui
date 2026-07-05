import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/datasources/zip_package_downloader.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/usecases/extract_and_store_pdfs.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

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
    pdfId1 = encodePdfId('ColAdultos/001.pdf');
    pdfId2 = encodePdfId('ColAdultos/002.pdf');
    pdfId3 = encodePdfId('ColAdultos/003.pdf');
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('extract_store_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = openOfflineTestIsar(tempDir);
    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: pdfStoragePortFor(store),
      local: OfflinePdfLocalDatasource(isar),
    );
    useCase = ExtractAndStorePdfs(
      repository,
      pdfStoragePortFor(store),
      ZipPackageDownloader(Dio(), pdfStoragePortFor(store)),
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
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

  test('propaga unmatchedEntries do ZIP no ExtractResult', () async {
    final zipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/001.pdf': pdfBytes,
        'ColAdultos/extra.pdf': pdfBytes,
      },
    );

    final result = await useCase(
      zipPath: zipPath,
      expectedPdfIds: [pdfId1],
      materialCategory: 'Partitura',
    );

    expect(result.storedCount, 1);
    expect(result.unmatchedPdfIds, contains('ColAdultos/extra.pdf'));
  });

  test('emite checkpoint intra-part a cada 50 PDFs indexados', () async {
    const pdfCount = 55;
    final pdfIds = List.generate(
      pdfCount,
      (i) =>
          encodePdfId('ColAdultos/${(i + 1).toString().padLeft(3, '0')}.pdf'),
    );
    final zipEntries = {
      for (var i = 0; i < pdfCount; i++)
        'ColAdultos/${(i + 1).toString().padLeft(3, '0')}.pdf': pdfBytes,
    };

    final zipPath = await createSampleZip(dir: tempDir, pdfEntries: zipEntries);
    final checkpoints = <int>[];

    await useCase(
      zipPath: zipPath,
      expectedPdfIds: pdfIds,
      materialCategory: 'Partitura',
      onProgressCheckpoint: (count) async {
        checkpoints.add(count);
      },
    );

    expect(checkpoints, [50]);
  });

  test('resume intra-part não re-escreve PDFs já indexados', () async {
    final marker1 = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x01]);
    final marker2 = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x02]);
    final marker3 = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x03]);

    await repository.upsert(
      pdfId: pdfId1,
      bytes: marker1,
      category: 'ColAdultos',
    );

    final zipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/001.pdf': marker3,
        'ColAdultos/002.pdf': marker2,
        'ColAdultos/003.pdf': marker3,
      },
    );

    await useCase(
      zipPath: zipPath,
      expectedPdfIds: [pdfId1, pdfId2, pdfId3],
      materialCategory: 'Partitura',
      startFromPdfIndex: 1,
    );

    final entry1 = await repository.lookup(pdfId1);
    expect(entry1, isNotNull);
    expect(
      await File(entry1!.absolutePath).readAsBytes(),
      marker1,
      reason: 'PDF já indexado não deve ser sobrescrito no resume',
    );

    final entry2 = await repository.lookup(pdfId2);
    expect(entry2, isNotNull);
    expect(await File(entry2!.absolutePath).readAsBytes(), marker2);

    final entry3 = await repository.lookup(pdfId3);
    expect(entry3, isNotNull);
    expect(await File(entry3!.absolutePath).readAsBytes(), marker3);
  });

  test('resume reprocessa prefixo do checkpoint sem arquivo válido', () async {
    final marker1 = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x01]);
    final marker2 = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x02]);
    final marker3 = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x03]);

    await repository.upsert(
      pdfId: pdfId1,
      bytes: marker1,
      category: 'ColAdultos',
    );

    final entry1 = await repository.findIndexEntry(pdfId1);
    expect(entry1, isNotNull);
    await File(entry1!.absolutePath).delete();

    final zipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/001.pdf': marker3,
        'ColAdultos/002.pdf': marker2,
        'ColAdultos/003.pdf': marker3,
      },
    );

    final result = await useCase(
      zipPath: zipPath,
      expectedPdfIds: [pdfId1, pdfId2, pdfId3],
      materialCategory: 'Partitura',
      startFromPdfIndex: 1,
    );

    expect(result.storedCount, 3);
    expect(result.skippedCount, 0);

    final restored1 = await repository.lookup(pdfId1);
    expect(restored1, isNotNull);
    expect(await File(restored1!.absolutePath).readAsBytes(), marker3);
  });
}
