import 'dart:io';

import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_smoke_');
    isar = await Isar.open(
      [LouvorCacheSchema, OfflinePdfIndexSchema],
      directory: tempDir.path,
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('CRUD LouvorCache com lookup por pdfId indexado', () async {
    final entry = LouvorCache()
      ..pdfId = 'abc123'
      ..nome = 'Louvor Teste'
      ..numero = '001'
      ..categoria = 'ColAdultos'
      ..classificacao = 'Partitura'
      ..pdf = 'assets/ColAdultos/001.pdf'
      ..groupId = '001:louvor-teste';

    await isar.writeTxn(() async {
      await isar.louvorCaches.put(entry);
    });

    final byPdfId =
        await isar.louvorCaches.filter().pdfIdEqualTo('abc123').findFirst();
    expect(byPdfId, isNotNull);
    expect(byPdfId!.nome, 'Louvor Teste');

    byPdfId.nome = 'Louvor Atualizado';
    await isar.writeTxn(() async {
      await isar.louvorCaches.put(byPdfId);
    });

    final updated = await isar.louvorCaches.get(byPdfId.id);
    expect(updated?.nome, 'Louvor Atualizado');

    await isar.writeTxn(() async {
      await isar.louvorCaches.delete(byPdfId.id);
    });
    expect(await isar.louvorCaches.count(), 0);
  });

  test('CRUD OfflinePdfIndex com lookup por pdfId indexado', () async {
    final downloadedAt = DateTime(2026, 6, 8, 12, 0);
    final index = OfflinePdfIndex()
      ..pdfId = 'xyz789'
      ..storagePath = '/data/offline/ColAdultos/001.pdf'
      ..category = 'ColAdultos'
      ..fileSize = 4096
      ..downloadedAt = downloadedAt;

    await isar.writeTxn(() async {
      await isar.offlinePdfIndexs.put(index);
    });

    final byPdfId =
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo('xyz789').findFirst();
    expect(byPdfId, isNotNull);
    expect(byPdfId!.storagePath, '/data/offline/ColAdultos/001.pdf');
    expect(byPdfId.fileSize, 4096);
    expect(byPdfId.downloadedAt, downloadedAt);

    await isar.writeTxn(() async {
      await isar.offlinePdfIndexs.delete(byPdfId.id);
    });
    expect(await isar.offlinePdfIndexs.count(), 0);
  });
}
