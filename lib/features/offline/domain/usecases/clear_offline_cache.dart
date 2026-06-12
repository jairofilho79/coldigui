import '../../data/datasources/offline_available_store.dart';
import '../../data/datasources/offline_bulk_checkpoint_store.dart';
import '../../data/datasources/pdf_local_store.dart';
import '../repositories/offline_pdf_repository.dart';

/// UC-10 — Limpar cache offline (Fase 3.6).
///
/// Reset atômico: clear [OfflinePdfIndex] + remove tree [OfflineConfig.pdfStorageSubdir]
/// + checkpoint bulk + `OFFLINE_AVAILABLE=FALSE` ([OfflineAvailableStore]).
class ClearOfflineCache {
  ClearOfflineCache(
    this._repository,
    this._store,
    this._checkpointStore,
    this._offlineAvailableStore,
  );

  final OfflinePdfRepository _repository;
  final PdfLocalStore _store;
  final OfflineBulkCheckpointStore _checkpointStore;
  final OfflineAvailableStore _offlineAvailableStore;

  Future<void> call() async {
    await _repository.clearAll();
    await _store.deleteTree();
    await _checkpointStore.clear();
    await _offlineAvailableStore.clear();
  }
}
