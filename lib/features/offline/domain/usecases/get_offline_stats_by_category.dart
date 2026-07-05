import 'dart:math' show min;

import '../../../catalog/data/datasources/catalog_local_datasource.dart';
import '../../../catalog/domain/constants/catalog_materials.dart';
import '../entities/offline_pdf_entry.dart';
import '../entities/offline_stats.dart';
import '../ports/pdf_storage_port.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/offline_material_resolver.dart';

/// UC-10 — Estatísticas por material de UI (Fase 3.6).
///
/// Contagem baixada e faltantes usam [OfflinePdfRepository.lookupBatch] —
/// mesma regra de “PDF offline válido” que [DownloadMissingPdfs].
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
    final validPdfIds = await _collectValidPdfIds(entries);

    final byCategory = {
      for (final material in CatalogMaterials.uiMaterials) material: 0,
    };

    for (final entry in entries) {
      if (!validPdfIds.contains(entry.pdfId)) continue;

      final categoria = pdfIdToCategoria[entry.pdfId] ?? entry.category;
      final material = OfflineMaterialResolver.toUiMaterial(categoria);
      if (material == null) continue;
      byCategory[material] = (byCategory[material] ?? 0) + 1;
    }

    final missingByCategory = includeMissing
        ? _countMissing(
            pdfIdToCategoria: pdfIdToCategoria,
            validPdfIds: validPdfIds,
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

  Future<Set<String>> _collectValidPdfIds(List<OfflinePdfEntry> entries) async {
    if (entries.isEmpty) return {};

    const batchSize = 50;
    final validPdfIds = <String>{};
    for (var i = 0; i < entries.length; i += batchSize) {
      final batch = entries.sublist(i, min(i + batchSize, entries.length));
      final pdfIds = batch.map((e) => e.pdfId).toSet();
      validPdfIds.addAll(await _repository.lookupBatch(pdfIds));
    }
    return validPdfIds;
  }

  Map<String, int> _countMissing({
    required Map<String, String> pdfIdToCategoria,
    required Set<String> validPdfIds,
  }) {
    final missingByCategory = {
      for (final material in CatalogMaterials.uiMaterials) material: 0,
    };

    for (final entry in pdfIdToCategoria.entries) {
      if (validPdfIds.contains(entry.key)) continue;

      final material = OfflineMaterialResolver.toUiMaterial(entry.value);
      if (material == null) continue;
      missingByCategory[material] = missingByCategory[material]! + 1;
    }

    return missingByCategory;
  }
}
