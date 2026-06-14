import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/offline/data/utils/zip_pdf_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_test_helpers.dart';

void main() {
  late Directory tempDir;

  final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);
  final htmlBytes = Uint8List.fromList([
    0x3C,
    0x68,
    0x74,
    0x6D,
    0x6C,
  ]); // <html

  late String pdfId1;
  late String pdfId2;
  late String pdfId3;

  setUpAll(() {
    pdfId1 = encodePdfId('ColAdultos/001.pdf');
    pdfId2 = encodePdfId('ColAdultos/002.pdf');
    pdfId3 = encodePdfId('ColAdultos/003.pdf');
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zip_extract_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('extrai PDFs válidos do ZIP via streaming', () async {
    final rootDir = Directory('${tempDir.path}/pdfs');
    await rootDir.create(recursive: true);

    final zipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/001.pdf': pdfBytes,
        'ColAdultos/002.pdf': pdfBytes,
        'ColAdultos/003.pdf': pdfBytes,
      },
    );

    final result = extractZipPdfs(
      ZipExtractParams(
        zipPath: zipPath,
        rootPath: rootDir.path,
        expectedPdfIds: [pdfId1, pdfId2, pdfId3],
        skipPdfIds: const [],
      ),
    );

    expect(result.items, hasLength(3));
    expect(result.unmatchedEntries, isEmpty);
    for (final item in result.items) {
      expect(File(item.absolutePath).existsSync(), isTrue);
      expect(item.fileSize, greaterThan(0));
    }
  });

  test('pula PDFs já indexados e conta entradas sem correspondência', () async {
    final rootDir = Directory('${tempDir.path}/pdfs');
    await rootDir.create(recursive: true);

    final zipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/001.pdf': pdfBytes,
        'ColAdultos/002.pdf': pdfBytes,
        'ColAdultos/unknown.pdf': pdfBytes,
      },
    );

    final result = extractZipPdfs(
      ZipExtractParams(
        zipPath: zipPath,
        rootPath: rootDir.path,
        expectedPdfIds: [pdfId1, pdfId2],
        skipPdfIds: [pdfId1],
      ),
    );

    expect(result.items, hasLength(1));
    expect(result.items.single.pdfId, pdfId2);
    expect(result.unmatchedEntries, ['ColAdultos/unknown.pdf']);
  });

  test('rejeita conteúdo sem magic bytes %PDF', () async {
    final rootDir = Directory('${tempDir.path}/pdfs');
    await rootDir.create(recursive: true);

    final zipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/001.pdf': htmlBytes,
        'ColAdultos/002.pdf': pdfBytes,
      },
    );

    final result = extractZipPdfs(
      ZipExtractParams(
        zipPath: zipPath,
        rootPath: rootDir.path,
        expectedPdfIds: [pdfId1, pdfId2],
        skipPdfIds: const [],
      ),
    );

    expect(result.items, hasLength(1));
    expect(result.items.single.pdfId, pdfId2);
    expect(result.failedPdfIds, [pdfId1]);
    expect(File('${rootDir.path}/ColAdultos/001.pdf').existsSync(), isFalse);
  });
}
