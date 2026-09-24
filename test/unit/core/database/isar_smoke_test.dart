import 'dart:io';

import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_smoke_');
    isar = Isar.open(schemas: [OfflinePdfIndexSchema], directory: tempDir.path);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('CRUD OfflinePdfIndex com lookup por pdfId indexado', () async {
    final downloadedAt = DateTime(2026, 6, 8, 12, 0);
    final index = OfflinePdfIndex()
      ..pdfId = 'xyz789'
      ..storagePath = '/data/offline/ColAdultos/001.pdf'
      ..category = 'ColAdultos'
      ..fileSize = 4096
      ..downloadedAt = downloadedAt;

    isar.write((isar) {
      final coll = isar.offlinePdfIndexs;
      index.id = coll.autoIncrement();
      coll.put(index);
    });

    final byPdfId = isar.offlinePdfIndexs
        .where()
        .pdfIdEqualTo('xyz789')
        .findFirst();
    expect(byPdfId, isNotNull);
    expect(byPdfId!.storagePath, '/data/offline/ColAdultos/001.pdf');
    expect(byPdfId.fileSize, 4096);
    expect(byPdfId.downloadedAt, downloadedAt);

    await isar.write((isar) {
      isar.offlinePdfIndexs.delete(byPdfId.id);
    });
    expect(isar.offlinePdfIndexs.count(), 0);
  });
}
