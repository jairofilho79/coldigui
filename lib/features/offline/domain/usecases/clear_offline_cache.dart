import '../../../catalog/data/datasources/catalog_local_datasource.dart';
import '../../../catalog/domain/constants/catalog_materials.dart';
import '../../data/datasources/offline_available_store.dart';
import '../../data/datasources/offline_bulk_categories_store.dart';
import '../../data/datasources/offline_bulk_checkpoint_store.dart';
import '../../data/datasources/offline_selected_categories_store.dart';
import '../../data/datasources/pdf_local_store.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/offline_material_resolver.dart';

/// UC-10 — Limpar cache offline (Fase 3.6).
///
/// Remove PDFs das [materials] selecionadas (índice + arquivo).
/// Wipe total quando o índice ficar vazio: tree + checkpoint + bulk/seleção +
/// `OFFLINE_AVAILABLE=FALSE`.
class ClearOfflineCache {
  ClearOfflineCache(
    this._repository,
    this._catalogLocal,
    this._store,
    this._checkpointStore,
    this._bulkCategoriesStore,
    this._selectedCategoriesStore,
    this._offlineAvailableStore,
  );

  final OfflinePdfRepository _repository;
  final CatalogLocalDatasource _catalogLocal;
  final PdfLocalStore _store;
  final OfflineBulkCheckpointStore _checkpointStore;
  final OfflineBulkCategoriesStore _bulkCategoriesStore;
  final OfflineSelectedCategoriesStore _selectedCategoriesStore;
  final OfflineAvailableStore _offlineAvailableStore;

  /// Retorna `true` quando o índice ficou vazio (wipe total).
  Future<bool> call({required Set<String> materials}) async {
    final scope =
        materials.where(CatalogMaterials.uiMaterials.contains).toSet();
    if (scope.isEmpty) return false;

    final entries = await _repository.listAll();
    if (entries.isEmpty) return false;

    final pdfIdToCategoria = await _catalogLocal.loadPdfIdToCategoriaMap();
    final toRemove = <String>{};

    for (final entry in entries) {
      final categoria = pdfIdToCategoria[entry.pdfId] ?? entry.category;
      final material = OfflineMaterialResolver.toUiMaterial(categoria);
      if (material != null && scope.contains(material)) {
        toRemove.add(entry.pdfId);
      }
    }

    if (toRemove.isEmpty) return false;

    for (final pdfId in toRemove) {
      await _repository.remove(pdfId);
    }

    await _bulkCategoriesStore.removeCategories(scope);

    final checkpoint = await _checkpointStore.load();
    if (checkpoint != null && checkpoint.categories.any(scope.contains)) {
      await _checkpointStore.clear();
    }

    final remaining = await _repository.listAll();
    if (remaining.isEmpty) {
      await _fullClear();
      return true;
    }
    return false;
  }

  Future<void> _fullClear() async {
    await _store.deleteTree();
    await _checkpointStore.clear();
    await _bulkCategoriesStore.clear();
    await _selectedCategoriesStore.clear();
    await _offlineAvailableStore.clear();
  }
}
