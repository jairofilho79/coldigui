import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/offline_pdf_index.dart';
import '../../../../core/database/storage_unavailable_exception.dart';

/// CRUD Isar para [OfflinePdfIndex] — sem validação de disco (Fase 3.1).
///
/// Em modo degradado (`_isar == null`) as **leituras** devolvem vazio e as
/// **escritas** lançam [StorageUnavailableException] — nunca fingem sucesso
/// (spec C.1 / B5).
///
/// [onIndexChanged] avisa quem deriva estado do índice (o mapa de
/// disponibilidade, A5) depois de cada escrita que muda **quais** PDFs estão
/// no índice ou se são persistentes. `touchLastAccessed*` não avisa: só mexe
/// no LRU, e a disponibilidade não muda. O datasource fica em `data/` e não
/// conhece Riverpod — quem injeta o callback é o provider de DI.
class OfflinePdfLocalDatasource {
  const OfflinePdfLocalDatasource(this._isar, {this.onIndexChanged});

  const OfflinePdfLocalDatasource.unavailable()
    : _isar = null,
      onIndexChanged = null;

  final Isar? _isar;

  /// Chamado após cada escrita que altera a disponibilidade (ver classe).
  final void Function()? onIndexChanged;

  /// Lookup O(1) por [pdfId] — sem validação de disco.
  Future<OfflinePdfIndex?> findByPdfId(String pdfId) async {
    final isar = _isar;
    if (isar == null) return null;
    return isar.offlinePdfIndexs.where().pdfIdEqualTo(pdfId).findFirst();
  }

  /// Lookup por [storagePath] absoluto — sem validação de disco.
  Future<OfflinePdfIndex?> findByStoragePath(String storagePath) async {
    final isar = _isar;
    if (isar == null) return null;
    return isar.offlinePdfIndexs
        .where()
        .storagePathEqualTo(storagePath)
        .findFirst();
  }

  /// Busca entradas do índice para [pdfIds] — sem validação de disco.
  Future<List<OfflinePdfIndex>> findByPdfIds(Set<String> pdfIds) async {
    if (pdfIds.isEmpty) return const [];
    final isar = _isar;
    if (isar == null) return const [];

    return isar.offlinePdfIndexs
        .where()
        .anyOf(pdfIds, (q, pdfId) => q.pdfIdEqualTo(pdfId))
        .findAll();
  }

  /// Candidatos LRU para eviction — ordenados do mais antigo ao mais novo.
  Future<List<OfflinePdfIndex>> findOldestForEviction({
    required int limit,
    int offset = 0,
  }) async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.offlinePdfIndexs
        .where()
        .isPersistentEqualTo(false)
        .sortByLastAccessedAt()
        .thenByDownloadedAt()
        .findAll(offset: offset, limit: limit);
  }

  /// Upsert por `pdfId` único em transação Isar.
  Future<void> put(OfflinePdfIndex index) async {
    final isar = _requireIsar('put');
    await isar.write((isar) {
      _putByPdfId(isar.offlinePdfIndexs, index);
    });
    onIndexChanged?.call();
  }

  /// Remove entrada por [pdfId] — idempotente se ausente.
  Future<void> deleteByPdfId(String pdfId) async {
    final isar = _requireIsar('deleteByPdfId');
    await isar.write((isar) {
      final coll = isar.offlinePdfIndexs;
      final existing = coll.where().pdfIdEqualTo(pdfId).findFirst();
      if (existing != null) {
        coll.delete(existing.id);
      }
    });
    onIndexChanged?.call();
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
  Future<List<OfflinePdfIndex>> findAll() async => findAllSync();

  /// Lista completa do índice, **síncrona** — sem validar arquivos no disco.
  ///
  /// O Isar Plus responde consultas sem `await`; é isso que deixa o mapa de
  /// disponibilidade (A5) ser um `Provider` puro, lido uma vez por mudança do
  /// índice em vez de uma query por card.
  List<OfflinePdfIndex> findAllSync() {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.offlinePdfIndexs.where().findAll();
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
    final isar = _requireIsar('touchLastAccessedBatch');

    await isar.write((isar) {
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
    final isar = _requireIsar('putAllByPdfId');
    await isar.write((isar) {
      final coll = isar.offlinePdfIndexs;
      for (final index in indexes) {
        _putByPdfId(coll, index);
      }
    });
    onIndexChanged?.call();
  }

  /// Marca todas as entradas como persistentes — migração v2 (bulk legado).
  Future<void> markAllPersistent() async {
    final isar = _requireIsar('markAllPersistent');
    await isar.write((isar) {
      final coll = isar.offlinePdfIndexs;
      final all = coll.where().findAll();
      for (final index in all) {
        if (index.isPersistent) continue;
        index.isPersistent = true;
        coll.put(index);
      }
    });
    onIndexChanged?.call();
  }

  /// Remove todas as entradas do índice offline (UC-10 clear cache).
  Future<void> clearAll() async {
    final isar = _requireIsar('clearAll');
    await isar.write((isar) {
      isar.offlinePdfIndexs.clear();
    });
    onIndexChanged?.call();
  }

  /// Remove entradas cujo [pdfId] está em [pdfIds].
  Future<int> deleteByPdfIds(Set<String> pdfIds) async {
    if (pdfIds.isEmpty) return 0;
    final isar = _requireIsar('deleteByPdfIds');

    var removed = 0;
    await isar.write((isar) {
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
    if (removed > 0) onIndexChanged?.call();
    return removed;
  }

  /// Isar obrigatório nas escritas — [StorageUnavailableException] se ausente.
  Isar _requireIsar(String operation) {
    final isar = _isar;
    if (isar == null) {
      throw StorageUnavailableException('offline.$operation');
    }
    return isar;
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
