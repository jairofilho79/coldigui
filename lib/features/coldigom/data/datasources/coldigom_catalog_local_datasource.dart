import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/coldigom_praise_cache.dart';
import '../../../../core/database/storage_unavailable_exception.dart';

/// CRUD Isar de [ColdigomPraiseCache] — o catálogo Coldigom local (O3).
///
/// Em modo degradado (`_isar == null`) as **leituras** devolvem vazio e as
/// **escritas** lançam [StorageUnavailableException] — nunca fingem sucesso
/// (mesma regra de `OfflinePdfLocalDatasource`). Dois escritores passam por
/// aqui: o sync total ([replaceAll], vence sempre) e a adoção dos «novos» da
/// pesquisa ([upsertMany]).
class ColdigomCatalogLocalDatasource {
  const ColdigomCatalogLocalDatasource(this._isar);

  const ColdigomCatalogLocalDatasource.unavailable() : _isar = null;

  final Isar? _isar;

  bool get isAvailable => _isar != null;

  /// Substitui o catálogo inteiro (clear + put) numa transação.
  Future<void> replaceAll(List<ColdigomPraiseCache> rows) async {
    final isar = _requireIsar('replaceAll');
    await isar.write((isar) {
      final coll = isar.coldigomPraiseCaches;
      coll.clear();
      for (final row in rows) {
        if (row.id == 0) row.id = coll.autoIncrement();
        coll.put(row);
      }
    });
  }

  /// Upsert por `praiseId` — os louvores que a pesquisa remota trouxe e o
  /// catálogo local ainda não tinha (§6).
  Future<void> upsertMany(List<ColdigomPraiseCache> rows) async {
    if (rows.isEmpty) return;
    final isar = _requireIsar('upsertMany');
    await isar.write((isar) {
      final coll = isar.coldigomPraiseCaches;
      for (final row in rows) {
        final existing = coll.where().praiseIdEqualTo(row.praiseId).findFirst();
        if (existing != null) {
          row.id = existing.id;
        } else if (row.id == 0) {
          row.id = coll.autoIncrement();
        }
        coll.put(row);
      }
    });
  }

  /// Catálogo inteiro, **síncrono** — o Isar Plus responde sem `await`, e é
  /// isso que deixa a hidratação e o índice serem valores derivados.
  List<ColdigomPraiseCache> findAllSync() {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.coldigomPraiseCaches.where().findAll();
  }

  /// Linha de um praise (leitor de letra), ou `null`.
  ColdigomPraiseCache? findByPraiseIdSync(String praiseId) {
    final isar = _isar;
    if (isar == null || praiseId.isEmpty) return null;
    return isar.coldigomPraiseCaches
        .where()
        .praiseIdEqualTo(praiseId)
        .findFirst();
  }

  int count() => _isar?.coldigomPraiseCaches.count() ?? 0;

  Isar _requireIsar(String operation) {
    final isar = _isar;
    if (isar == null) {
      throw StorageUnavailableException('coldigom_catalog.$operation');
    }
    return isar;
  }
}
