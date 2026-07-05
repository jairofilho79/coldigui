import '../../../catalog/data/datasources/catalog_local_datasource.dart';
import '../../../catalog/domain/constants/catalog_materials.dart';
import '../ports/pdf_storage_port.dart';
import '../entities/offline_stats.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/offline_material_resolver.dart';

/// UC-10 — Estatísticas por material de UI (Fase 3.6).
///
/// Contagem baixada: índice Isar + [CatalogLocalDatasource] +
/// [OfflineMaterialResolver]. Faltantes: catálogo Isar (D1 local) como SSOT —
/// independente do manifest de packages.
class GetOfflineStatsByCategory {
  const GetOfflineStatsByCategory(
    this._repository,
    this._catalogLocal,
    this._store,
  );

  final OfflinePdfRepository _repository;
  final CatalogLocalDatasource _catalogLocal;
  final PdfStoragePort _store;

  Future<OfflineStats> call({bool includeMissing = true}) async {
    final entries = await _repository.listAll();
    final pdfIdToCategoria = await _catalogLocal.loadPdfIdToCategoriaMap();

    final byCategory = {
      for (final material in CatalogMaterials.uiMaterials) material: 0,
    };

    for (final entry in entries) {
      final categoria = pdfIdToCategoria[entry.pdfId] ?? entry.category;
      final material = OfflineMaterialResolver.toUiMaterial(categoria);
      if (material == null) continue;
      byCategory[material] = (byCategory[material] ?? 0) + 1;
    }

    final missingByCategory = includeMissing
        ? await _countMissing(
            indexedPdfIds: entries.map((entry) => entry.pdfId).toSet(),
          )
        : {for (final material in CatalogMaterials.uiMaterials) material: 0};

    final totalDiskUsageBytes = await _store.getTotalOfflineBytes();

    return OfflineStats(
      byCategory: byCategory,
      missingByCategory: missingByCategory,
      totalDiskUsageBytes: totalDiskUsageBytes,
      missingCountReliable: includeMissing,
    );
  }

  Future<Map<String, int>> _countMissing({
    required Set<String> indexedPdfIds,
  }) async {
    final pdfIdToCategoria = await _catalogLocal.loadPdfIdToCategoriaMap();

    final missingByCategory = {
      for (final material in CatalogMaterials.uiMaterials) material: 0,
    };

    for (final entry in pdfIdToCategoria.entries) {
      final pdfId = entry.key;
      if (indexedPdfIds.contains(pdfId)) continue;

      final material = OfflineMaterialResolver.toUiMaterial(entry.value);
      if (material == null) continue;
      missingByCategory[material] = missingByCategory[material]! + 1;
    }

    return missingByCategory;
  }
}
