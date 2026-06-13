import '../../../catalog/data/datasources/catalog_local_datasource.dart';
import '../../../catalog/domain/constants/catalog_materials.dart';
import '../../data/datasources/offline_manifest_remote_datasource.dart';
import '../entities/offline_manifest.dart';
import '../entities/offline_stats.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/offline_material_resolver.dart';

/// UC-10 — Estatísticas por material de UI (Fase 3.6).
///
/// Contagem baixada: índice Isar + [CatalogLocalDatasource] +
/// [OfflineMaterialResolver]. Faltantes: comparação com manifest remoto
/// (`includeMissing: false` ignora rede e retorna `missingByCategory` vazio).
class GetOfflineStatsByCategory {
  const GetOfflineStatsByCategory(
    this._repository,
    this._catalogLocal,
    this._manifestDatasource,
  );

  final OfflinePdfRepository _repository;
  final CatalogLocalDatasource _catalogLocal;
  final OfflineManifestRemoteDatasource _manifestDatasource;

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

    var missingByCategory = {
      for (final material in CatalogMaterials.uiMaterials) material: 0,
    };
    if (includeMissing) {
      try {
        missingByCategory = await _countMissing(
          manifest: await _manifestDatasource.fetchManifest(),
          indexedPdfIds: entries.map((entry) => entry.pdfId).toSet(),
        );
      } on Object {
        missingByCategory = const {};
      }
    }

    final totalDiskUsageBytes =
        entries.fold<int>(0, (sum, entry) => sum + entry.fileSize);

    return OfflineStats(
      byCategory: byCategory,
      missingByCategory: missingByCategory,
      totalDiskUsageBytes: totalDiskUsageBytes,
    );
  }

  Future<Map<String, int>> _countMissing({
    required OfflineManifest manifest,
    required Set<String> indexedPdfIds,
  }) async {
    final missingByCategory = {
      for (final material in CatalogMaterials.uiMaterials) material: 0,
    };

    for (final material in CatalogMaterials.uiMaterials) {
      final package = manifest.packages[material];
      if (package == null) continue;

      for (final part in package.parts) {
        for (final pdfId in part.pdfs) {
          if (!indexedPdfIds.contains(pdfId)) {
            missingByCategory[material] = missingByCategory[material]! + 1;
          }
        }
      }
    }

    return missingByCategory;
  }
}
