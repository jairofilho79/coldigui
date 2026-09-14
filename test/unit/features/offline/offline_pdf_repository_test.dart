import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/louvor_cache.dart';

import 'offline_test_helpers.dart';

import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/core/utils/pdf_path_normalizer.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/ports/pdf_storage_port.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

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

/// Delega tudo ao [_delegate] real, exceto [getTotalOfflineBytes] — prova
/// que a quota (A6) não escaneia mais o store, só o índice Isar.
class _ThrowingTotalBytesStore implements PdfStoragePort {
  _ThrowingTotalBytesStore(this._delegate);

  final PdfStoragePort _delegate;

  @override
  Future<String> get rootPath => _delegate.rootPath;

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) =>
      _delegate.writeAtomic(bytes, relPath);

  @override
  Future<bool> exists(String storageKey) => _delegate.exists(storageKey);

  @override
  Future<void> delete(String storageKey) => _delegate.delete(storageKey);

  @override
  Future<void> deleteTree() => _delegate.deleteTree();

  @override
  Future<int> getTotalOfflineBytes() {
    throw StateError(
      'getTotalOfflineBytes não deve ser chamado por totalCachedBytes (A6)',
    );
  }

  @override
  Future<List<String>> listOrphans(Set<String> indexedStorageKeys) =>
      _delegate.listOrphans(indexedStorageKeys);

  @override
  Future<Uint8List?> readBytes(String storageKey, {int? maxBytes}) =>
      _delegate.readBytes(storageKey, maxBytes: maxBytes);

  @override
  Future<void> purgeLegacyStorage() => _delegate.purgeLegacyStorage();
}

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late PdfLocalStore store;
  late OfflinePdfRepositoryImpl repository;
  late OfflinePdfLocalDatasource local;

  const category = 'ColAdultos';
  const relPath = 'ColAdultos/001.pdf';
  late String pdfId;

  setUpAll(() async {
    pdfId = _encodePdfId(relPath);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline_repo_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = Isar.open(
      schemas: [LouvorCacheSchema, OfflinePdfIndexSchema],
      directory: tempDir.path,
    );

    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    local = OfflinePdfLocalDatasource(isar);
    repository = OfflinePdfRepositoryImpl(
      store: pdfStoragePortFor(store),
      local: local,
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
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
      isTrue,
    );
    expect(await File(entry.absolutePath).exists(), isTrue);
    expect(
      entry.absolutePath,
      endsWith(PdfPathNormalizer.getPdfRelPath(pdfId)),
    );

    final index = isar.offlinePdfIndexs.where().pdfIdEqualTo(pdfId).findFirst();
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
    await isar.write((isar) {
      final index = isar.offlinePdfIndexs
          .where()
          .pdfIdEqualTo(pdfId)
          .findFirst();
      index!.lastAccessedAt = staleAccess;
      isar.offlinePdfIndexs.put(index);
    });

    await repository.lookup(pdfId);
    await repository.flushPendingTouchLastAccessed();

    final indexAfter = isar.offlinePdfIndexs
        .where()
        .pdfIdEqualTo(pdfId)
        .findFirst();
    expect(indexAfter!.lastAccessedAt, isNotNull);
    expect(indexAfter.lastAccessedAt!.isAfter(staleAccess), isTrue);
  });

  test('lookup debounce evita write txn repetida em 5 minutos', () async {
    final bytes = _validPdfBytes();
    await repository.upsert(pdfId: pdfId, bytes: bytes, category: category);

    await repository.lookup(pdfId);
    await repository.flushPendingTouchLastAccessed();

    final indexAfterFirst = isar.offlinePdfIndexs
        .where()
        .pdfIdEqualTo(pdfId)
        .findFirst();
    final firstTouch = indexAfterFirst!.lastAccessedAt!;

    await repository.lookup(pdfId);
    await repository.flushPendingTouchLastAccessed();

    final indexAfterSecond = isar.offlinePdfIndexs
        .where()
        .pdfIdEqualTo(pdfId)
        .findFirst();
    expect(indexAfterSecond!.lastAccessedAt, firstTouch);
  });

  test('findPdfIdByAbsolutePath resolve pdfId do índice', () async {
    final bytes = _validPdfBytes();
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: category,
    );

    expect(await repository.findPdfIdByAbsolutePath(entry.absolutePath), pdfId);
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
    final index = isar.offlinePdfIndexs.where().pdfIdEqualTo(pdfId).findFirst();
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
    expect(isar.offlinePdfIndexs.where().pdfIdEqualTo(pdfId).count(), 0);
  });

  test('removeMany apaga N PDFs (disco + índice) com uma única notificação de '
      'mudança — não N como remove() em laço faria', () async {
    var indexChanges = 0;
    final trackedLocal = OfflinePdfLocalDatasource(
      isar,
      onIndexChanged: () => indexChanges++,
    );
    final trackedRepo = OfflinePdfRepositoryImpl(
      store: pdfStoragePortFor(store),
      local: trackedLocal,
    );

    final id1 = _encodePdfId('ColAdultos/many-a.pdf');
    final id2 = _encodePdfId('ColAdultos/many-b.pdf');
    final id3 = _encodePdfId('ColAdultos/many-c.pdf');
    final entries = [
      await trackedRepo.upsert(
        pdfId: id1,
        bytes: _validPdfBytes(),
        category: 'ColAdultos',
      ),
      await trackedRepo.upsert(
        pdfId: id2,
        bytes: _validPdfBytes(),
        category: 'ColAdultos',
      ),
      await trackedRepo.upsert(
        pdfId: id3,
        bytes: _validPdfBytes(),
        category: 'ColAdultos',
      ),
    ];
    indexChanges = 0; // só a remoção importa daqui pra frente.

    await trackedRepo.removeMany({id1, id2, id3});

    expect(indexChanges, 1);
    expect(isar.offlinePdfIndexs.where().count(), 0);
    for (final entry in entries) {
      expect(await File(entry.absolutePath).exists(), isFalse);
    }
  });

  test('removeMany é idempotente (conjunto vazio ou pdfId ausente)', () async {
    await repository.removeMany({});
    await repository.removeMany({'inexistente'});
    // Não lança — só o comportamento importa aqui.
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

  test('totalCachedBytes soma bytes no store', () async {
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

  test('totalCachedBytes soma o índice Isar sem chamar o store (A6)', () async {
    final throwingStore = _ThrowingTotalBytesStore(pdfStoragePortFor(store));
    final repositoryWithThrowingStore = OfflinePdfRepositoryImpl(
      store: throwingStore,
      local: OfflinePdfLocalDatasource(isar),
    );

    final id1 = _encodePdfId('ColAdultos/c.pdf');
    final id2 = _encodePdfId('ColAdultos/d.pdf');

    await repositoryWithThrowingStore.upsert(
      pdfId: id1,
      bytes: _validPdfBytes(List.filled(1000, 1)),
      category: 'ColAdultos',
    );
    await repositoryWithThrowingStore.upsert(
      pdfId: id2,
      bytes: _validPdfBytes(List.filled(234, 1)),
      category: 'ColAdultos',
    );

    expect(await repositoryWithThrowingStore.totalCachedBytes(), 1242);
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

    test('evictOldestPdfs não remove PDFs persistentes', () async {
      final persistentId = _encodePdfId('ColAdultos/persistent.pdf');
      final lruId = _encodePdfId('ColAdultos/lru.pdf');

      await repository.upsert(
        pdfId: persistentId,
        bytes: _validPdfBytes([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
        category: 'ColAdultos',
        isPersistent: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repository.upsert(
        pdfId: lruId,
        bytes: _validPdfBytes([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
        category: 'ColAdultos',
      );

      final freed = await repository.evictOldestPdfs(targetBytes: 100);

      expect(await repository.lookup(persistentId), isNotNull);
      expect(await repository.lookup(lruId), isNull);
      expect(freed, greaterThan(0));
    });
  });

  test('clearAll remove todas as entradas do índice', () async {
    await repository.upsert(
      pdfId: pdfId,
      bytes: _validPdfBytes(),
      category: category,
    );

    await repository.clearAll();

    expect(isar.offlinePdfIndexs.where().count(), 0);
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
      expect(isar.offlinePdfIndexs.where().pdfIdEqualTo(pdfId).count(), 0);
    });

    test('lookup miss e purge para bytes aleatórios', () async {
      final entry = await repository.upsert(
        pdfId: pdfId,
        bytes: Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04]),
        category: category,
      );

      expect(await repository.lookup(pdfId), isNull);

      expect(await File(entry.absolutePath).exists(), isFalse);
      expect(isar.offlinePdfIndexs.where().pdfIdEqualTo(pdfId).count(), 0);
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
      expect(isar.offlinePdfIndexs.where().pdfIdEqualTo(pdfId).count(), 1);
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
      expect(isar.offlinePdfIndexs.where().pdfIdEqualTo(corruptId).count(), 0);
    });

    test(
      'lookupWithIndexState purge corrupto retorna hasIndexEntry false',
      () async {
        await repository.upsert(
          pdfId: pdfId,
          bytes: Uint8List.fromList([0xCA, 0xFE, 0xBA, 0xBE]),
          category: category,
        );

        final result = await repository.lookupWithIndexState(pdfId);
        expect(result.$1, isNull);
        expect(result.$2, isFalse);
      },
    );
  });

  group('modo degradado (Isar indisponível)', () {
    late OfflinePdfRepositoryImpl degraded;

    setUp(() {
      degraded = OfflinePdfRepositoryImpl(
        store: pdfStoragePortFor(store),
        local: const OfflinePdfLocalDatasource.unavailable(),
      );
    });

    test('upsert grava o PDF e devolve a entrada mesmo sem índice', () async {
      final bytes = _validPdfBytes();

      final entry = await degraded.upsert(
        pdfId: pdfId,
        bytes: bytes,
        category: category,
      );

      expect(entry.pdfId, pdfId);
      expect(entry.fileSize, bytes.length);
      expect(await File(entry.absolutePath).exists(), isTrue);
      expect(await File(entry.absolutePath).readAsBytes(), bytes);
    });

    test('upsertBatch continua propagando a falha de índice', () async {
      expect(
        () => degraded.upsertBatch([
          OfflinePdfBatchItem(
            pdfId: pdfId,
            bytes: _validPdfBytes(),
            category: category,
          ),
        ]),
        throwsA(isA<StorageUnavailableException>()),
      );
    });

    test('clearAll continua propagando a falha de índice', () {
      expect(
        () => degraded.clearAll(),
        throwsA(isA<StorageUnavailableException>()),
      );
    });
  });

  test(
    'markPersistent promove só os presentes e devolve quantos mudaram',
    () async {
      // 'lru-1'/'lru-2' literais não decodificam como pdfId (o repositório
      // exige Base64 URL-safe de um path, via PdfPathNormalizer) — usa-se
      // encodePdfId como o resto do arquivo (ex.: teste de eviction acima).
      final lru1 = _encodePdfId('ColAdultos/lru-1.pdf');
      final lru2 = _encodePdfId('ColAdultos/lru-2.pdf');
      await repository.upsert(
        pdfId: lru1,
        bytes: _validPdfBytes(),
        category: 'x',
      );
      await repository.upsert(
        pdfId: lru2,
        bytes: _validPdfBytes(),
        category: 'x',
        isPersistent: true,
      );

      final changed = await local.markPersistent({lru1, lru2, 'ausente'});

      expect(changed, 1);
      expect((await repository.findIndexEntry(lru1))!.isPersistent, isTrue);
      expect(await local.markPersistent({lru1}), 0);
    },
  );
}
