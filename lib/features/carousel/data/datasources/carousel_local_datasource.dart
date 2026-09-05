import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/carousel_entry.dart';

/// Leitura e limpeza da coleção `CarouselEntry` — **só para a migração** (D3).
///
/// A seleção deixou de ter persistência própria: a lista ativa é a única fonte
/// de verdade. O que resta aqui é o que `MigrateCarouselStore` precisa para
/// aproveitar o carousel do último boot e depois esvaziar a coleção. A
/// `@Collection()` continua no schema Isar (remoção numa onda futura).
///
/// Sem Isar ([CarouselLocalDatasource.unavailable]) a leitura devolve `[]` e a
/// limpeza é no-op: a migração simplesmente não roda neste boot.
class CarouselLocalDatasource {
  const CarouselLocalDatasource(this._isar);

  const CarouselLocalDatasource.unavailable() : _isar = null;

  final Isar? _isar;

  /// Ids da coleção antiga, ordenados por `sortOrder`.
  Future<List<String>> getOrderedPdfIds() async {
    final isar = _isar;
    if (isar == null) return const [];
    final entries = isar.carouselEntrys.where().sortBySortOrder().findAll();
    return entries.map((e) => e.pdfId).toList(growable: false);
  }

  /// Remove todas as entradas — idempotente.
  Future<void> clear() async {
    final isar = _isar;
    if (isar == null) return;
    await isar.write((isar) {
      isar.carouselEntrys.clear();
    });
  }
}
