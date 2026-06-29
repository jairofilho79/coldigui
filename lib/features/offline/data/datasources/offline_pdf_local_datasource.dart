import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/offline_pdf_index.dart';

/// CRUD Isar para [OfflinePdfIndex] — sem validação de disco (Fase 3.1).
class OfflinePdfLocalDatasource {
  const OfflinePdfLocalDatasource(this._isar);

  final Isar _isar;

  /// Lookup O(1) por [pdfId] — sem validação de disco.
  Future<OfflinePdfIndex?> findByPdfId(String pdfId) async {
    return _isar.offlinePdfIndexs.where().pdfIdEqualTo(pdfId).findFirst();
  }

  /// Lookup por [storagePath] absoluto — sem validação de disco.
  Future<OfflinePdfIndex?> findByStoragePath(String storagePath) async {
    return _isar.offlinePdfIndexs
        .where()
        .storagePathEqualTo(storagePath)
        .findFirst();
  }

  /// Busca entradas do índice para [pdfIds] — sem validação de disco.
  Future<List<OfflinePdfIndex>> findByPdfIds(Set<String> pdfIds) async {
    if (pdfIds.isEmpty) return const [];

    final indexes = _isar.offlinePdfIndexs
        .where()
        .anyOf(pdfIds, (q, pdfId) => q.pdfIdEqualTo(pdfId))
        .findAll();
    return indexes;
  }

  /// Candidatos LRU para eviction — ordenados do mais antigo ao mais novo.
  ///
  /// Exclui PDFs com [OfflinePdfIndex.isPersistent] = `true`.
  Future<List<OfflinePdfIndex>> findOldestForEviction({
    required int limit,
    int offset = 0,
  }) async {
    return _isar.offlinePdfIndexs
        .where()
        .isPersistentEqualTo(false)
        .sortByLastAccessedAt()
        .thenByDownloadedAt()
        .findAll(offset: offset, limit: limit);
  }

  /// Upsert por `pdfId` único em transação Isar.
  Future<void> put(OfflinePdfIndex index) async {
    await _isar.write((isar) {
      _putByPdfId(isar.offlinePdfIndexs, index);
    });
  }

  /// Remove entrada por [pdfId] — idempotente se ausente.
  Future<void> deleteByPdfId(String pdfId) async {
    await _isar.write((isar) {
      final coll = isar.offlinePdfIndexs;
      final existing = coll.where().pdfIdEqualTo(pdfId).findFirst();
      if (existing != null) {
        coll.delete(existing.id);
      }
    });
  }

  /// Contagem por [OfflinePdfIndex.category] — agregação em memória.
  Future<Map<String, int>> countByCategory() async {
    final all = await findAll();
    final counts = <String, int>{};
    for (final index in all) {
      counts.update(index.category, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Lista completa do índice — sem validar arquivos no disco.
  Future<List<OfflinePdfIndex>> findAll() async {
    return _isar.offlinePdfIndexs.where().findAll();
  }

  /// Soma [OfflinePdfIndex.fileSize] — quota LRU sem scan filesystem.
  Future<int> sumFileSizes() async {
    final all = await findAll();
    return all.fold<int>(0, (sum, index) => sum + index.fileSize);
  }

  /// Atualiza [OfflinePdfIndex.lastAccessedAt] após lookup bem-sucedido.
  Future<void> touchLastAccessed(String pdfId, DateTime accessedAt) async {
    await touchLastAccessedBatch({pdfId: accessedAt});
  }

  /// Atualiza [OfflinePdfIndex.lastAccessedAt] em lote — uma write txn.
  Future<void> touchLastAccessedBatch(Map<String, DateTime> touches) async {
    if (touches.isEmpty) return;

    await _isar.write((isar) {
      final coll = isar.offlinePdfIndexs;
      final pdfIds = touches.keys.toList();
      final indexes = coll
          .where()
          .anyOf(pdfIds, (q, pdfId) => q.pdfIdEqualTo(pdfId))
          .findAll();
      for (final index in indexes) {
        index.lastAccessedAt = touches[index.pdfId];
        coll.put(index);
      }
    });
  }

  /// Upsert em lote por `pdfId` em uma única transação (bulk UC-09).
  Future<void> putAllByPdfId(List<OfflinePdfIndex> indexes) async {
    if (indexes.isEmpty) return;
    await _isar.write((isar) {
      final coll = isar.offlinePdfIndexs;
      for (final index in indexes) {
        _putByPdfId(coll, index);
      }
    });
  }

  /// Marca todas as entradas como persistentes — migração v2 (bulk legado).
  Future<void> markAllPersistent() async {
    await _isar.write((isar) {
      final coll = isar.offlinePdfIndexs;
      final all = coll.where().findAll();
      for (final index in all) {
        if (index.isPersistent) continue;
        index.isPersistent = true;
        coll.put(index);
      }
    });
  }

  /// Remove todas as entradas do índice offline (UC-10 clear cache).
  Future<void> clearAll() async {
    await _isar.write((isar) {
      isar.offlinePdfIndexs.clear();
    });
  }

  /// Remove entradas cujo [pdfId] está em [pdfIds].
  Future<int> deleteByPdfIds(Set<String> pdfIds) async {
    if (pdfIds.isEmpty) return 0;

    var removed = 0;
    await _isar.write((isar) {
      final coll = isar.offlinePdfIndexs;
      final existing = coll
          .where()
          .anyOf(pdfIds, (q, pdfId) => q.pdfIdEqualTo(pdfId))
          .findAll();
      for (final index in existing) {
        if (coll.delete(index.id)) {
          removed++;
        }
      }
    });
    return removed;
  }

  void _putByPdfId(
    IsarCollection<int, OfflinePdfIndex> coll,
    OfflinePdfIndex index,
  ) {
    final existing = coll.where().pdfIdEqualTo(index.pdfId).findFirst();
    if (existing != null) {
      index.id = existing.id;
    } else if (index.id == 0) {
      index.id = coll.autoIncrement();
    }
    coll.put(index);
  }
}
