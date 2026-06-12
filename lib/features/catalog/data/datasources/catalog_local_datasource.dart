import 'package:isar/isar.dart';

import '../../../../core/database/collections/louvor_cache.dart';
import '../../domain/entities/louvor.dart';
import '../mappers/louvor_cache_mapper.dart';

/// Cache local Isar do catálogo (ADR-001) — UC-01/12.
///
/// Persiste e lê [Louvor] via schema [LouvorCache] para busca offline.
class CatalogLocalDatasource {
  const CatalogLocalDatasource(this._isar);

  final Isar _isar;

  /// Substitui todo o cache Isar pelos [louvores] (clear + putAll em uma txn).
  Future<void> saveLouvores(List<Louvor> louvores) async {
    final caches = louvores.map((l) => l.toCache()).toList();
    await _isar.writeTxn(() async {
      await _isar.louvorCaches.clear();
      await _isar.louvorCaches.putAll(caches);
    });
  }

  /// Carrega todos os louvores do cache local para uso offline.
  Future<List<Louvor>> loadLouvores() async {
    final caches = await _isar.louvorCaches.where().findAll();
    return caches.map((c) => c.toEntity()).toList();
  }

  /// Mapa pdfId → [Louvor.categoria] para agregação offline (UC-10).
  ///
  /// Usado por [GetOfflineStatsByCategory] para mapear material de UI.
  Future<Map<String, String>> loadPdfIdToCategoriaMap() async {
    final caches = await _isar.louvorCaches.where().findAll();
    return {for (final cache in caches) cache.pdfId: cache.categoria};
  }
}
