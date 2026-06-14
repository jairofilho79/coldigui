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

Uint8List _validPdfBytes([List<int> extra = const []]) {
  return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, ...extra]);
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
    final bytes = _validPdfBytes([1, 2, 3]);
    await repository.upsert(pdfId: pdfId, bytes: bytes, category: category);

    final found = await repository.lookup(pdfId);
    expect(found, isNotNull);
    expect(found!.pdfId, pdfId);
    expect(found.fileSize, bytes.length);
  });

  test('lookup atualiza lastAccessedAt no índice', () async {
    final bytes = _validPdfBytes();
    await repository.upsert(pdfId: pdfId, bytes: bytes, category: category);

    final staleAccess = DateTime.now().subtract(const Duration(hours: 1));
    await isar.writeTxn(() async {
      final index =
          await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).findFirst();
      index!.lastAccessedAt = staleAccess;
      await isar.offlinePdfIndexs.put(index);
    });

    await repository.lookup(pdfId);
    await repository.flushPendingTouchLastAccessed();

    final indexAfter =
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).findFirst();
    expect(indexAfter!.lastAccessedAt, isNotNull);
    expect(indexAfter.lastAccessedAt!.isAfter(staleAccess), isTrue);
  });

  test('lookup debounce evita write txn repetida em 5 minutos', () async {
    final bytes = _validPdfBytes();
    await repository.upsert(pdfId: pdfId, bytes: bytes, category: category);

    await repository.lookup(pdfId);
    await repository.flushPendingTouchLastAccessed();

    final indexAfterFirst =
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).findFirst();
    final firstTouch = indexAfterFirst!.lastAccessedAt!;

    await repository.lookup(pdfId);
    await repository.flushPendingTouchLastAccessed();

    final indexAfterSecond =
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).findFirst();
    expect(indexAfterSecond!.lastAccessedAt, firstTouch);
  });

  test('findPdfIdByAbsolutePath resolve pdfId do índice', () async {
    final bytes = _validPdfBytes();
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: category,
    );

    expect(
      await repository.findPdfIdByAbsolutePath(entry.absolutePath),
      pdfId,
    );
    expect(
      await repository.findPdfIdByAbsolutePath('/inexistente/foo.pdf'),
      isNull,
    );
  });

  test('lookup miss quando índice ausente', () async {
    expect(await repository.lookup('inexistente'), isNull);
  });

  test('lookup miss quando arquivo apagado externamente', () async {
    final bytes = _validPdfBytes();
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
    final bytes = _validPdfBytes();
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
    final bytes = _validPdfBytes();
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
    final bytes = _validPdfBytes();
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
      bytes: _validPdfBytes(),
      category: 'ColAdultos',
    );
    await repository.upsert(
      pdfId: id2,
      bytes: _validPdfBytes(),
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
      bytes: _validPdfBytes(),
      category: 'ColAdultos',
    );
    await repository.upsert(
      pdfId: id2,
      bytes: _validPdfBytes(),
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
      bytes: _validPdfBytes(),
      category: 'ColAdultos',
    );
    await repository.upsert(
      pdfId: id2,
      bytes: _validPdfBytes(),
      category: 'ColAdultos',
    );
    await repository.upsert(
      pdfId: id3,
      bytes: _validPdfBytes(),
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
      bytes: _validPdfBytes(),
      category: category,
    );

    expect(entry.absolutePath, isNot(contains('assets/')));
    expect(entry.absolutePath, endsWith('ColAdultos/001.pdf'));
  });

  test('totalCachedBytes soma fileSize do índice', () async {
    final id1 = _encodePdfId('ColAdultos/a.pdf');
    final id2 = _encodePdfId('ColAdultos/b.pdf');

    await repository.upsert(
      pdfId: id1,
      bytes: _validPdfBytes([1, 2, 3, 4, 5]),
      category: 'ColAdultos',
    );
    await repository.upsert(
      pdfId: id2,
      bytes: _validPdfBytes([1, 2]),
      category: 'ColAdultos',
    );

    expect(await repository.totalCachedBytes(), 15);
  });

  group('evictOldestPdfs LRU', () {
    test('remove PDF menos recentemente acessado primeiro', () async {
      final oldestId = _encodePdfId('ColAdultos/oldest.pdf');
      final middleId = _encodePdfId('ColAdultos/middle.pdf');
      final newestId = _encodePdfId('ColAdultos/newest.pdf');

      await repository.upsert(
        pdfId: oldestId,
        bytes: _validPdfBytes([1, 2, 3, 4]),
        category: 'ColAdultos',
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repository.upsert(
        pdfId: middleId,
        bytes: _validPdfBytes([1, 2, 3, 4, 5, 6]),
        category: 'ColAdultos',
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repository.upsert(
        pdfId: newestId,
        bytes: _validPdfBytes([1, 2, 3, 4, 5, 6, 7]),
        category: 'ColAdultos',
      );

      await repository.lookup(middleId);
      await repository.lookup(newestId);

      final freed = await repository.evictOldestPdfs(targetBytes: 4);
      expect(freed, 8);
      expect(await repository.lookup(oldestId), isNull);
      expect(await repository.lookup(middleId), isNotNull);
      expect(await repository.lookup(newestId), isNotNull);
    });

    test('não remove PDFs em excludePdfIds', () async {
      final protectedId = _encodePdfId('ColAdultos/protected.pdf');
      final evictId = _encodePdfId('ColAdultos/evict.pdf');

      await repository.upsert(
        pdfId: protectedId,
        bytes: _validPdfBytes([1, 2, 3, 4]),
        category: 'ColAdultos',
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repository.upsert(
        pdfId: evictId,
        bytes: _validPdfBytes([1, 2, 3, 4, 5, 6]),
        category: 'ColAdultos',
      );

      final freed = await repository.evictOldestPdfs(
        targetBytes: 100,
        excludePdfIds: {protectedId},
      );

      expect(freed, 10);
      expect(await repository.lookup(protectedId), isNotNull);
      expect(await repository.lookup(evictId), isNull);
    });
  });

  test('clearAll remove todas as entradas do índice', () async {
    await repository.upsert(
      pdfId: pdfId,
      bytes: _validPdfBytes(),
      category: category,
    );

    await repository.clearAll();

    expect(
      await isar.offlinePdfIndexs.where().count(),
      0,
    );
  });

  group('validação magic bytes %PDF', () {
    test('lookup miss e purge para arquivo vazio', () async {
      final entry = await repository.upsert(
        pdfId: pdfId,
        bytes: Uint8List(0),
        category: category,
      );

      expect(await repository.lookup(pdfId), isNull);

      expect(await File(entry.absolutePath).exists(), isFalse);
      expect(
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).count(),
        0,
      );
    });

    test('lookup miss e purge para bytes aleatórios', () async {
      final entry = await repository.upsert(
        pdfId: pdfId,
        bytes: Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04]),
        category: category,
      );

      expect(await repository.lookup(pdfId), isNull);

      expect(await File(entry.absolutePath).exists(), isFalse);
      expect(
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).count(),
        0,
      );
    });

    test('lookup hit para PDF válido com header %PDF', () async {
      final bytes = _validPdfBytes([0x2D, 0x31, 0x2E, 0x34]);
      final entry = await repository.upsert(
        pdfId: pdfId,
        bytes: bytes,
        category: category,
      );

      final found = await repository.lookup(pdfId);
      expect(found, isNotNull);
      expect(found!.absolutePath, entry.absolutePath);
      expect(
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).count(),
        1,
      );
    });

    test('lookup hit para PDF truncado com header válido', () async {
      final bytes = _validPdfBytes([0x2D, 0x31, 0x2E, 0x34, 0x0A, 0x25]);
      final entry = await repository.upsert(
        pdfId: pdfId,
        bytes: bytes,
        category: category,
      );

      final found = await repository.lookup(pdfId);
      expect(found, isNotNull);
      expect(found!.absolutePath, entry.absolutePath);
    });

    test('lookupBatch exclui e purge corruptos', () async {
      final validId = _encodePdfId('ColAdultos/valid.pdf');
      final corruptId = _encodePdfId('ColAdultos/corrupt.pdf');

      await repository.upsert(
        pdfId: validId,
        bytes: _validPdfBytes(),
        category: 'ColAdultos',
      );
      final corruptEntry = await repository.upsert(
        pdfId: corruptId,
        bytes: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
        category: 'ColAdultos',
      );

      final found = await repository.lookupBatch({validId, corruptId});
      expect(found, {validId});
      expect(await File(corruptEntry.absolutePath).exists(), isFalse);
      expect(
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(corruptId).count(),
        0,
      );
    });

    test('lookupWithIndexState purge corrupto retorna hasIndexEntry false',
        () async {
      await repository.upsert(
        pdfId: pdfId,
        bytes: Uint8List.fromList([0xCA, 0xFE, 0xBA, 0xBE]),
        category: category,
      );

      final result = await repository.lookupWithIndexState(pdfId);
      expect(result.$1, isNull);
      expect(result.$2, isFalse);
    });
  });
}
