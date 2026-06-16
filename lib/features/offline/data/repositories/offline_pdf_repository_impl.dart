import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import '../../../../core/database/collections/offline_pdf_index.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../domain/entities/offline_pdf_batch_item.dart';
import '../../domain/entities/offline_pdf_entry.dart';
import '../../domain/repositories/offline_pdf_repository.dart';
import '../../domain/utils/offline_category_resolver.dart';
import '../datasources/offline_pdf_local_datasource.dart';
import '../datasources/pdf_local_store.dart';

/// Orquestra [PdfLocalStore] + [OfflinePdfLocalDatasource] (Fase 3.1).
class OfflinePdfRepositoryImpl implements OfflinePdfRepository {
  OfflinePdfRepositoryImpl({
    required PdfLocalStore store,
    required OfflinePdfLocalDatasource local,
  })  : _store = store,
        _local = local;

  static const _touchDebounce = Duration(minutes: 5);
  static const _touchFlushThreshold = 20;
  static const _evictionBatchSize = 100;

  final PdfLocalStore _store;
  final OfflinePdfLocalDatasource _local;
  final Map<String, DateTime> _pendingTouchAt = {};

  @override
  Future<OfflinePdfEntry?> lookup(String pdfId) async {
    final (entry, _) = await lookupWithIndexState(pdfId);
    return entry;
  }

  @override
  Future<(OfflinePdfEntry? entry, bool hasIndexEntry)> lookupWithIndexState(
    String pdfId,
  ) async {
    final index = await _local.findByPdfId(pdfId);
    if (index == null) return (null, false);

    switch (await _validateIndexFile(index)) {
      case _IndexFileValidation.valid:
        final now = DateTime.now();
        _recordTouch(pdfId, now, index.lastAccessedAt);
        index.lastAccessedAt = _pendingTouchAt[pdfId] ?? index.lastAccessedAt;
        if (_pendingTouchAt.length >= _touchFlushThreshold) {
          await flushPendingTouchLastAccessed();
        }
        return (_toEntry(index), true);
      case _IndexFileValidation.missing:
        return (null, true);
      case _IndexFileValidation.corrupt:
        await _purgeInvalidIndexFile(index);
        return (null, false);
    }
  }

  @override
  Future<Set<String>> lookupBatch(Set<String> pdfIds) async {
    if (pdfIds.isEmpty) return {};

    final indexes = await _local.findByPdfIds(pdfIds);
    if (indexes.isEmpty) return {};

    final validIds = <String>{};
    const batchSize = 50;
    for (var i = 0; i < indexes.length; i += batchSize) {
      final batch = indexes.sublist(i, min(i + batchSize, indexes.length));
      final results = await Future.wait(batch.map(_validateIndexFile));
      for (var j = 0; j < batch.length; j++) {
        switch (results[j]) {
          case _IndexFileValidation.valid:
            validIds.add(batch[j].pdfId);
          case _IndexFileValidation.corrupt:
            await _purgeInvalidIndexFile(batch[j]);
          case _IndexFileValidation.missing:
            break;
        }
      }
    }
    return validIds;
  }

  @override
  Future<OfflinePdfEntry?> findIndexEntry(String pdfId) async {
    final index = await _local.findByPdfId(pdfId);
    if (index == null) return null;
    return _toEntry(index);
  }

  @override
  Future<OfflinePdfEntry> upsert({
    required String pdfId,
    required Uint8List bytes,
    required String category,
    bool isPersistent = false,
  }) async {
    final existing = await _local.findByPdfId(pdfId);
    final persistent = isPersistent || (existing?.isPersistent ?? false);

    final relPath = _resolveStorageRelPath(pdfId);
    final absolutePath = await _store.writeAtomic(bytes, relPath);
    final now = DateTime.now();

    final index = OfflinePdfIndex()
      ..pdfId = pdfId
      ..storagePath = absolutePath
      ..category = category
      ..fileSize = bytes.length
      ..downloadedAt = now
      ..lastAccessedAt = now
      ..isPersistent = persistent;

    await _local.put(index);

    return OfflinePdfEntry(
      pdfId: pdfId,
      absolutePath: absolutePath,
      category: category,
      fileSize: bytes.length,
      downloadedAt: now,
      lastAccessedAt: now,
      isPersistent: persistent,
    );
  }

  @override
  Future<void> remove(String pdfId) async {
    final index = await _local.findByPdfId(pdfId);
    if (index == null) return;

    await _store.delete(index.storagePath);
    await _local.deleteByPdfId(pdfId);
    _pendingTouchAt.remove(pdfId);
  }

  @override
  Future<String?> findPdfIdByAbsolutePath(String absolutePath) async {
    final index = await _local.findByStoragePath(absolutePath);
    return index?.pdfId;
  }

  @override
  Future<Map<String, int>> countByCategory() => _local.countByCategory();

  @override
  Future<List<OfflinePdfEntry>> listAll() async {
    final indexes = await _local.findAll();
    return indexes.map(_toEntry).toList();
  }

  @override
  Future<void> indexExtractedBatch(List<ExtractedPdfItem> items) async {
    if (items.isEmpty) return;

    final now = DateTime.now();
    final indexes = items
        .map(
          (item) => OfflinePdfIndex()
            ..pdfId = item.pdfId
            ..storagePath = item.absolutePath
            ..category = OfflineCategoryResolver.fromPdfId(item.pdfId)
            ..fileSize = item.fileSize
            ..downloadedAt = now
            ..lastAccessedAt = now
            ..isPersistent = true,
        )
        .toList();

    await _local.putAllByPdfId(indexes);
  }

  @override
  Future<void> upsertBatch(List<OfflinePdfBatchItem> items) async {
    if (items.isEmpty) return;

    final now = DateTime.now();
    final indexes = <OfflinePdfIndex>[];

    for (final item in items) {
      final relPath = _resolveStorageRelPath(item.pdfId);
      final absolutePath = await _store.writeAtomic(item.bytes, relPath);
      indexes.add(
        OfflinePdfIndex()
          ..pdfId = item.pdfId
          ..storagePath = absolutePath
          ..category = item.category
          ..fileSize = item.bytes.length
          ..downloadedAt = now
          ..lastAccessedAt = now
          ..isPersistent = true,
      );
    }

    await _local.putAllByPdfId(indexes);
  }

  @override
  Future<int> removeIndexEntries(Set<String> pdfIds) =>
      _local.deleteByPdfIds(pdfIds);

  @override
  Future<void> clearAll() => _local.clearAll();

  @override
  Future<int> totalCachedBytes() => _local.sumFileSizes();

  @override
  Future<void> flushPendingTouchLastAccessed() async {
    if (_pendingTouchAt.isEmpty) return;

    final batch = Map<String, DateTime>.from(_pendingTouchAt);
    _pendingTouchAt.clear();
    await _local.touchLastAccessedBatch(batch);
  }

  @override
  Future<int> evictOldestPdfs({
    required int targetBytes,
    Set<String> excludePdfIds = const {},
  }) async {
    if (targetBytes <= 0) return 0;

    await flushPendingTouchLastAccessed();

    var offset = 0;
    var freed = 0;

    while (freed < targetBytes) {
      final batch = await _local.findOldestForEviction(
        limit: _evictionBatchSize,
        offset: offset,
      );
      if (batch.isEmpty) break;

      var removedAny = false;
      for (final index in batch) {
        if (freed >= targetBytes) break;
        if (excludePdfIds.contains(index.pdfId)) continue;

        await remove(index.pdfId);
        freed += index.fileSize;
        removedAny = true;
      }

      offset = removedAny ? 0 : offset + _evictionBatchSize;
    }

    return freed;
  }

  void _recordTouch(
      String pdfId, DateTime now, DateTime? existingLastAccessed) {
    final lastKnown = _pendingTouchAt[pdfId] ?? existingLastAccessed;
    if (lastKnown != null && now.difference(lastKnown) < _touchDebounce) {
      return;
    }
    _pendingTouchAt[pdfId] = now;
  }

  static String _resolveStorageRelPath(String pdfId) {
    var rel = PdfPathNormalizer.getPdfRelPath(pdfId);
    if (rel.startsWith('assets/')) {
      rel = rel.substring('assets/'.length);
    }
    return rel;
  }

  Future<void> _purgeInvalidIndexFile(OfflinePdfIndex index) async {
    await _store.delete(index.storagePath);
    await _local.deleteByPdfId(index.pdfId);
  }

  static Future<_IndexFileValidation> _validateIndexFile(
    OfflinePdfIndex index,
  ) async {
    final stat = await FileStat.stat(index.storagePath);
    if (stat.type != FileSystemEntityType.file) {
      return _IndexFileValidation.missing;
    }
    if (stat.size < 4) return _IndexFileValidation.corrupt;

    final raf = await File(index.storagePath).open();
    try {
      final header = await raf.read(4);
      final validHeader = header.length == 4 &&
          header[0] == 0x25 &&
          header[1] == 0x50 &&
          header[2] == 0x44 &&
          header[3] == 0x46;
      return validHeader
          ? _IndexFileValidation.valid
          : _IndexFileValidation.corrupt;
    } finally {
      await raf.close();
    }
  }

  static OfflinePdfEntry _toEntry(OfflinePdfIndex index) => OfflinePdfEntry(
        pdfId: index.pdfId,
        absolutePath: index.storagePath,
        category: index.category,
        fileSize: index.fileSize,
        downloadedAt: index.downloadedAt,
        lastAccessedAt: index.lastAccessedAt,
        isPersistent: index.isPersistent,
      );
}

enum _IndexFileValidation { valid, missing, corrupt }
