/// Chaves de [SharedPreferences] e flags leves.
abstract final class StorageKeys {
  /// UC-09 — bulk concluído (`'TRUE'`). Gate da UI offline (UC-10 vs UC-09).
  /// **Não** usar como gate de abertura PDF (Fase 3 local-first).
  static const String offlineAvailable = 'OFFLINE_AVAILABLE';
  static const String pdfPreferredFitMode = 'pdfPreferredFitMode';
  static const String perfDebug = 'plpcjf_perf_debug';

  /// Checkpoint JSON do bulk download UC-09 (Fase 3.5).
  static const String offlineBulkCheckpoint = 'offlineBulkCheckpoint';

  /// Versão do layout offline nativo — [MigrateOfflineStorage] (Fase 3.6).
  static const String offlineStorageVersion = 'offlineStorageVersion';

  /// Timestamp (epoch ms) do último reconcile global UC-10 (backlog #12).
  static const String lastReconcileAt = 'lastReconcileAt';

  /// Timestamp ISO-8601 do último sync remoto do catálogo (UC-12).
  static const String catalogLastSyncAt = 'catalogLastSyncAt';

  /// Último checksum SHA-256 conhecido do manifest (UC-12 poll).
  static const String manifestChecksum = 'manifestChecksum';

  /// Timestamp (epoch ms) do último poll de checksum UC-12 (backlog #15).
  static const String lastChecksumPollAt = 'lastChecksumPollAt';
}
