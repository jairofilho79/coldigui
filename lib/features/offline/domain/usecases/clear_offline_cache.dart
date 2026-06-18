import '../../data/datasources/offline_available_store.dart';
import '../../data/datasources/offline_bulk_categories_store.dart';
import '../../data/datasources/offline_bulk_checkpoint_store.dart';
import '../../data/datasources/offline_selected_categories_store.dart';
import '../../data/datasources/pdf_local_store.dart';
import '../repositories/offline_pdf_repository.dart';

/// UC-10 — Limpar cache offline (Fase 3.6).
///
/// Reset atômico: clear [OfflinePdfIndex] + remove tree [OfflineConfig.pdfStorageSubdir]
/// + checkpoint bulk + categorias bulk/seleção + `OFFLINE_AVAILABLE=FALSE`.
class ClearOfflineCache {
  ClearOfflineCache(
    this._repository,
    this._store,
    this._checkpointStore,
    this._bulkCategoriesStore,
    this._selectedCategoriesStore,
    this._offlineAvailableStore,
  );

  final OfflinePdfRepository _repository;
  final PdfLocalStore _store;
  final OfflineBulkCheckpointStore _checkpointStore;
  final OfflineBulkCategoriesStore _bulkCategoriesStore;
  final OfflineSelectedCategoriesStore _selectedCategoriesStore;
  final OfflineAvailableStore _offlineAvailableStore;

  Future<void> call() async {
    await _repository.clearAll();
    await _store.deleteTree();
    await _checkpointStore.clear();
    await _bulkCategoriesStore.clear();
    await _selectedCategoriesStore.clear();
    await _offlineAvailableStore.clear();
  }
}
