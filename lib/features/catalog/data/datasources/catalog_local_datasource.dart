import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/louvor_cache.dart';
import '../../domain/entities/louvor.dart';
import '../mappers/louvor_cache_mapper.dart';

/// Linha enxuta do cache para o download em massa (UC-09/UC-10): `pdfId`,
/// `categoria` (filtro por material) e `pdf` (URL absoluta do manifest).
typedef CatalogPdfRow = ({String pdfId, String categoria, String pdf});

/// Cache local Isar do catálogo (ADR-001) — UC-01/12.
///
/// Persiste e lê [Louvor] via schema [LouvorCache] para busca offline.
class CatalogLocalDatasource {
  const CatalogLocalDatasource(this._isar);

  const CatalogLocalDatasource.unavailable() : _isar = null;

  final Isar? _isar;

  bool get isAvailable => _isar != null;

  /// Substitui todo o cache Isar pelos [louvores] (clear + putAll em uma txn).
  Future<void> saveLouvores(List<Louvor> louvores) async {
    final isar = _isar;
    if (isar == null) return;
    final caches = louvores.map((l) => l.toCache()).toList();
    await isar.write((isar) {
      final coll = isar.louvorCaches;
      coll.clear();
      for (final cache in caches) {
        if (cache.id == 0) {
          cache.id = coll.autoIncrement();
        }
        coll.put(cache);
      }
    });
  }

  /// Carrega todos os louvores do cache local para uso offline.
  Future<List<Louvor>> loadLouvores() async {
    final isar = _isar;
    if (isar == null) return const [];
    final caches = isar.louvorCaches.where().findAll();
    return caches.map((c) => c.toEntity()).toList();
  }

  /// Mapa pdfId → [Louvor.categoria] para agregação offline (UC-10).
  Future<Map<String, String>> loadPdfIdToCategoriaMap() async {
    final isar = _isar;
    if (isar == null) return const {};
    final caches = isar.louvorCaches.where().findAll();
    return {for (final cache in caches) cache.pdfId: cache.categoria};
  }

  /// Linhas ([CatalogPdfRow]) de todos os PDFs do cache, numa só leitura —
  /// o download em massa deriva daqui o filtro por categoria e a URL de cada
  /// PDF sem varrer `louvorCaches` duas vezes (UC-09/UC-10).
  Future<List<CatalogPdfRow>> loadPdfRows() async {
    final isar = _isar;
    if (isar == null) return const [];
    final caches = isar.louvorCaches.where().findAll();
    return [
      for (final cache in caches)
        (pdfId: cache.pdfId, categoria: cache.categoria, pdf: cache.pdf),
    ];
  }
}
