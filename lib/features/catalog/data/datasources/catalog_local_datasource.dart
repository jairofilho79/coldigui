import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/louvor_cache.dart';
import '../../domain/entities/louvor.dart';
import '../mappers/louvor_cache_mapper.dart';

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
}
