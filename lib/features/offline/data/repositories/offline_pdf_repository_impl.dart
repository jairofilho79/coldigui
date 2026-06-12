import 'dart:io';
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
  const OfflinePdfRepositoryImpl({
    required PdfLocalStore store,
    required OfflinePdfLocalDatasource local,
  })  : _store = store,
        _local = local;

  final PdfLocalStore _store;
  final OfflinePdfLocalDatasource _local;

  @override
  Future<OfflinePdfEntry?> lookup(String pdfId) async {
    final index = await _local.findByPdfId(pdfId);
    if (index == null) return null;

    final file = File(index.storagePath);
    if (!await file.exists()) return null;
    if (await file.length() == 0) return null;

    return _toEntry(index);
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
  }) async {
    final relPath = _resolveStorageRelPath(pdfId);
    final absolutePath = await _store.writeAtomic(bytes, relPath);
    final now = DateTime.now();

    final index = OfflinePdfIndex()
      ..pdfId = pdfId
      ..storagePath = absolutePath
      ..category = category
      ..fileSize = bytes.length
      ..downloadedAt = now;

    await _local.put(index);

    return OfflinePdfEntry(
      pdfId: pdfId,
      absolutePath: absolutePath,
      category: category,
      fileSize: bytes.length,
      downloadedAt: now,
    );
  }

  @override
  Future<void> remove(String pdfId) async {
    final index = await _local.findByPdfId(pdfId);
    if (index == null) return;

    await _store.delete(index.storagePath);
    await _local.deleteByPdfId(pdfId);
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
            ..downloadedAt = now,
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
          ..downloadedAt = now,
      );
    }

    await _local.putAllByPdfId(indexes);
  }

  @override
  Future<int> removeIndexEntries(Set<String> pdfIds) =>
      _local.deleteByPdfIds(pdfIds);

  @override
  Future<void> clearAll() => _local.clearAll();

  static String _resolveStorageRelPath(String pdfId) {
    var rel = PdfPathNormalizer.getPdfRelPath(pdfId);
    if (rel.startsWith('assets/')) {
      rel = rel.substring('assets/'.length);
    }
    return rel;
  }

  static OfflinePdfEntry _toEntry(OfflinePdfIndex index) => OfflinePdfEntry(
        pdfId: index.pdfId,
        absolutePath: index.storagePath,
        category: index.category,
        fileSize: index.fileSize,
        downloadedAt: index.downloadedAt,
      );
}
