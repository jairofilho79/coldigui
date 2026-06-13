import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/utils/pdf_path_normalizer.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

String _encodePdfId(String path) {
  return base64Url
      .encode(utf8.encode(path))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late PdfLocalStore store;
  late OfflinePdfRepositoryImpl repository;

  const category = 'ColAdultos';
  const relPath = 'ColAdultos/001.pdf';
  late String pdfId;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    pdfId = _encodePdfId(relPath);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline_repo_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = await Isar.open(
      [LouvorCacheSchema, OfflinePdfIndexSchema],
      directory: tempDir.path,
    );

    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: store,
      local: OfflinePdfLocalDatasource(isar),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('upsert grava arquivo no disco e registro Isar', () async {
    final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
    final before = DateTime.now();

    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: category,
    );

    expect(entry.pdfId, pdfId);
    expect(entry.category, category);
    expect(entry.fileSize, bytes.length);
    expect(
        entry.downloadedAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue);
    expect(await File(entry.absolutePath).exists(), isTrue);
    expect(
      entry.absolutePath,
      endsWith(PdfPathNormalizer.getPdfRelPath(pdfId)),
    );

    final index =
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).findFirst();
    expect(index, isNotNull);
    expect(index!.fileSize, bytes.length);
    expect(index.storagePath, entry.absolutePath);
  });

  test('lookup retorna hit após upsert', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    await repository.upsert(pdfId: pdfId, bytes: bytes, category: category);

    final found = await repository.lookup(pdfId);
    expect(found, isNotNull);
    expect(found!.pdfId, pdfId);
    expect(found.fileSize, bytes.length);
  });

  test('lookup miss quando índice ausente', () async {
    expect(await repository.lookup('inexistente'), isNull);
  });

  test('lookup miss quando arquivo apagado externamente', () async {
    final bytes = Uint8List.fromList([1]);
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: category,
    );

    await File(entry.absolutePath).delete();

    expect(await repository.lookup(pdfId), isNull);

    // Índice órfão permanece (reconcile 3.6).
    final index =
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).findFirst();
    expect(index, isNotNull);
  });

  test('lookupWithIndexState distingue órfão de ausente', () async {
    final bytes = Uint8List.fromList([1]);
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: category,
    );

    final hit = await repository.lookupWithIndexState(pdfId);
    expect(hit.$1, isNotNull);
    expect(hit.$2, isTrue);

    await File(entry.absolutePath).delete();

    final stale = await repository.lookupWithIndexState(pdfId);
    expect(stale.$1, isNull);
    expect(stale.$2, isTrue);

    final missing = await repository.lookupWithIndexState('inexistente');
    expect(missing.$1, isNull);
    expect(missing.$2, isFalse);
  });

  test('findIndexEntry retorna órfão sem validar disco', () async {
    final bytes = Uint8List.fromList([1]);
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: category,
    );

    await File(entry.absolutePath).delete();

    expect(await repository.findIndexEntry(pdfId), isNotNull);
    expect(await repository.findIndexEntry('inexistente'), isNull);
  });

  test('remove apaga disco e índice', () async {
    final bytes = Uint8List.fromList([1]);
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: category,
    );

    await repository.remove(pdfId);

    expect(await File(entry.absolutePath).exists(), isFalse);
    expect(
      await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).count(),
      0,
    );
  });

  test('lookupBatch retorna pdfIds com índice e arquivo válido', () async {
    final id1 = _encodePdfId('ColAdultos/a.pdf');
    final id2 = _encodePdfId('ColAdultos/b.pdf');
    final id3 = _encodePdfId('ColAdultos/c.pdf');

    await repository.upsert(
      pdfId: id1,
      bytes: Uint8List.fromList([1]),
      category: 'ColAdultos',
    );
    await repository.upsert(
      pdfId: id2,
      bytes: Uint8List.fromList([1]),
      category: 'ColAdultos',
    );

    final found = await repository.lookupBatch({id1, id2, id3});
    expect(found, {id1, id2});
  });

  test('lookupBatch exclui órfão sem arquivo no disco', () async {
    final id1 = _encodePdfId('ColAdultos/a.pdf');
    final id2 = _encodePdfId('ColAdultos/b.pdf');

    final entry1 = await repository.upsert(
      pdfId: id1,
      bytes: Uint8List.fromList([1]),
      category: 'ColAdultos',
    );
    await repository.upsert(
      pdfId: id2,
      bytes: Uint8List.fromList([1]),
      category: 'ColAdultos',
    );
    await File(entry1.absolutePath).delete();

    final found = await repository.lookupBatch({id1, id2});
    expect(found, {id2});
  });

  test('countByCategory agrega corretamente', () async {
    final id1 = _encodePdfId('ColAdultos/a.pdf');
    final id2 = _encodePdfId('ColAdultos/b.pdf');
    final id3 = _encodePdfId('ColJovens/c.pdf');

    await repository.upsert(
      pdfId: id1,
      bytes: Uint8List.fromList([1]),
      category: 'ColAdultos',
    );
    await repository.upsert(
      pdfId: id2,
      bytes: Uint8List.fromList([1]),
      category: 'ColAdultos',
    );
    await repository.upsert(
      pdfId: id3,
      bytes: Uint8List.fromList([1]),
      category: 'ColJovens',
    );

    final counts = await repository.countByCategory();
    expect(counts['ColAdultos'], 2);
    expect(counts['ColJovens'], 1);
  });

  test('path no disco segue getPdfRelPath sem prefixo assets/', () async {
    const pathWithAssets = 'assets/ColAdultos/001.pdf';
    final encodedId = _encodePdfId(pathWithAssets);

    final entry = await repository.upsert(
      pdfId: encodedId,
      bytes: Uint8List.fromList([1]),
      category: category,
    );

    expect(entry.absolutePath, isNot(contains('assets/')));
    expect(entry.absolutePath, endsWith('ColAdultos/001.pdf'));
  });

  test('clearAll remove todas as entradas do índice', () async {
    await repository.upsert(
      pdfId: pdfId,
      bytes: Uint8List.fromList([1]),
      category: category,
    );

    await repository.clearAll();

    expect(
      await isar.offlinePdfIndexs.where().count(),
      0,
    );
  });
}
