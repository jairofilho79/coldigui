import 'package:isar/isar.dart';

import '../../../../core/database/collections/carousel_entry.dart';

/// CRUD Isar para [CarouselEntry] (UC-05, Fase 4.1).
///
/// Todas as mutações usam `writeTxn`. [pdfId] é único no schema Isar.
class CarouselLocalDatasource {
  const CarouselLocalDatasource(this._isar);

  final Isar _isar;

  /// Entradas ordenadas por [CarouselEntry.sortOrder] ascendente.
  Future<List<CarouselEntry>> findAllOrdered() =>
      _isar.carouselEntrys.where().sortBySortOrder().findAll();

  /// Lookup O(1) por [pdfId] — sem validação de manifest.
  Future<CarouselEntry?> findByPdfId(String pdfId) =>
      _isar.carouselEntrys.filter().pdfIdEqualTo(pdfId).findFirst();

  /// Append ao final; no-op se [pdfId] já existe.
  Future<void> add(String pdfId) async {
    final existing = await findByPdfId(pdfId);
    if (existing != null) return;

    final all = await findAllOrdered();
    final nextOrder = all.isEmpty
        ? 0
        : all.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    final entry = CarouselEntry()
      ..pdfId = pdfId
      ..sortOrder = nextOrder;

    await _isar.writeTxn(() async {
      await _isar.carouselEntrys.putByPdfId(entry);
    });
  }

  /// Remove por [pdfId] e compacta [CarouselEntry.sortOrder] para 0..n-1.
  Future<void> remove(String pdfId) async {
    await _isar.writeTxn(() async {
      final existing =
          await _isar.carouselEntrys.filter().pdfIdEqualTo(pdfId).findFirst();
      if (existing == null) return;

      await _isar.carouselEntrys.delete(existing.id);

      final remaining =
          await _isar.carouselEntrys.where().sortBySortOrder().findAll();
      for (var i = 0; i < remaining.length; i++) {
        final entry = remaining[i];
        if (entry.sortOrder != i) {
          entry.sortOrder = i;
          await _isar.carouselEntrys.put(entry);
        }
      }
    });
  }

  /// Reescreve ordem; lança [ArgumentError] se o conjunto de IDs divergir.
  Future<void> reorder(List<String> orderedPdfIds) async {
    await _isar.writeTxn(() async {
      final current = await _isar.carouselEntrys.where().findAll();
      final currentIds = current.map((e) => e.pdfId).toSet();
      final targetIds = orderedPdfIds.toSet();

      if (currentIds.length != targetIds.length ||
          !currentIds.containsAll(targetIds)) {
        throw ArgumentError(
            'orderedPdfIds must match current carousel entries');
      }

      for (var i = 0; i < orderedPdfIds.length; i++) {
        final pdfId = orderedPdfIds[i];
        final entry =
            await _isar.carouselEntrys.filter().pdfIdEqualTo(pdfId).findFirst();
        if (entry == null) continue;
        entry.sortOrder = i;
        await _isar.carouselEntrys.put(entry);
      }
    });
  }

  /// Substitui toda a seleção — usado por Fase 4.3 [LoadPlaylistIntoCarousel].
  Future<void> replaceAll(List<String> orderedPdfIds) async {
    await _isar.writeTxn(() async {
      await _isar.carouselEntrys.clear();
      for (var i = 0; i < orderedPdfIds.length; i++) {
        final entry = CarouselEntry()
          ..pdfId = orderedPdfIds[i]
          ..sortOrder = i;
        await _isar.carouselEntrys.putByPdfId(entry);
      }
    });
  }

  /// Remove todas as entradas — idempotente.
  Future<void> clear() async {
    await _isar.writeTxn(() async {
      await _isar.carouselEntrys.clear();
    });
  }
}
