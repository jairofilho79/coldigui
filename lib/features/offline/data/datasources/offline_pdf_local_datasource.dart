import 'package:isar/isar.dart';

import '../../../../core/database/collections/offline_pdf_index.dart';

/// CRUD Isar para [OfflinePdfIndex] — sem validação de disco (Fase 3.1).
class OfflinePdfLocalDatasource {
  const OfflinePdfLocalDatasource(this._isar);

  final Isar _isar;

  /// Lookup O(1) por [pdfId] — sem validação de disco.
  Future<OfflinePdfIndex?> findByPdfId(String pdfId) =>
      _isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).findFirst();

  /// Upsert por `pdfId` único em transação Isar.
  Future<void> put(OfflinePdfIndex index) async {
    await _isar.writeTxn(() async {
      await _isar.offlinePdfIndexs.putByPdfId(index);
    });
  }

  /// Remove entrada por [pdfId] — idempotente se ausente.
  Future<void> deleteByPdfId(String pdfId) async {
    await _isar.writeTxn(() async {
      final existing =
          await _isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).findFirst();
      if (existing != null) {
        await _isar.offlinePdfIndexs.delete(existing.id);
      }
    });
  }

  /// Contagem por [OfflinePdfIndex.category] — agregação em memória.
  Future<Map<String, int>> countByCategory() async {
    final all = await _isar.offlinePdfIndexs.where().findAll();
    final counts = <String, int>{};
    for (final index in all) {
      counts.update(index.category, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Lista completa do índice — sem validar arquivos no disco.
  Future<List<OfflinePdfIndex>> findAll() =>
      _isar.offlinePdfIndexs.where().findAll();

  /// Upsert em lote por `pdfId` em uma única transação (bulk UC-09).
  Future<void> putAllByPdfId(List<OfflinePdfIndex> indexes) async {
    if (indexes.isEmpty) return;
    await _isar.writeTxn(() async {
      await _isar.offlinePdfIndexs.putAllByPdfId(indexes);
    });
  }

  /// Remove todas as entradas do índice offline (UC-10 clear cache).
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.offlinePdfIndexs.clear();
    });
  }

  /// Remove entradas cujo [pdfId] está em [pdfIds].
  Future<int> deleteByPdfIds(Set<String> pdfIds) async {
    if (pdfIds.isEmpty) return 0;

    var removed = 0;
    await _isar.writeTxn(() async {
      for (final pdfId in pdfIds) {
        final existing = await _isar.offlinePdfIndexs
            .filter()
            .pdfIdEqualTo(pdfId)
            .findFirst();
        if (existing != null) {
          await _isar.offlinePdfIndexs.delete(existing.id);
          removed++;
        }
      }
    });
    return removed;
  }
}
