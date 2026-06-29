import 'dart:io';

import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_smoke_');
    isar = Isar.open(
      schemas: [LouvorCacheSchema, OfflinePdfIndexSchema],
      directory: tempDir.path,
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
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

    isar.write((isar) {
      final coll = isar.louvorCaches;
      entry.id = coll.autoIncrement();
      coll.put(entry);
    });

    final byPdfId = isar.louvorCaches
        .where()
        .pdfIdEqualTo('abc123')
        .findFirst();
    expect(byPdfId, isNotNull);
    expect(byPdfId!.nome, 'Louvor Teste');

    byPdfId.nome = 'Louvor Atualizado';
    await isar.write((isar) {
      isar.louvorCaches.put(byPdfId);
    });

    final updated = isar.louvorCaches.get(byPdfId.id);
    expect(updated?.nome, 'Louvor Atualizado');

    await isar.write((isar) {
      isar.louvorCaches.delete(byPdfId.id);
    });
    expect(isar.louvorCaches.count(), 0);
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
