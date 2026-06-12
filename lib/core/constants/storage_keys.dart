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
}
