/// Limites e retry do store offline nativo (Fase 3).
///
/// [pdfStorageSubdir] — subpasta em ApplicationDocumentsDirectory (perene).
/// Constantes `sw*` e [pdfCacheName] são legado PWA — revisar na 3.1.
abstract final class OfflineConfig {
  /// Subdiretório de PDFs offline em documents — **não** usar cache/temp.
  static const String pdfStorageSubdir = 'plpcg_pdfs';
  static const String pdfCacheName = 'plpc-pdfs';
  static const Duration manifestCacheTtl = Duration(minutes: 5);
  static const Duration validationCacheTtl = Duration(hours: 24);
  static const Duration statsCacheTtl = Duration(minutes: 5);
  static const Duration swRegistrationTimeout = Duration(seconds: 5);
  static const Duration swReadyTimeout = Duration(milliseconds: 500);
  static const int defaultBatchSize = 10;

  /// Tentativas máximas de [FetchAndStorePdf] antes de propagar [DioException].
  static const int maxRetryAttempts = 3;

  /// Base do backoff linear entre tentativas de fetch on-demand (Fase 3.3).
  ///
  /// Delay efetivo: `retryBackoffBase * attempt` (500ms, 1s, 1.5s).
  static const Duration retryBackoffBase = Duration(milliseconds: 500);

  /// Tamanho de chunk para upsert Isar no bulk UC-09 (Fase 3.5).
  static const int bulkIsarChunkSize = 75;

  /// Subpasta transitória de ZIPs bulk sob `plpcg_pdfs/`.
  static const String zipTempSubdir = '_bulk_zips';

  /// Margem de segurança sobre `totalSize` do manifest antes do download.
  static const double diskSpaceSafetyMargin = 1.15;

  /// Debounce antes de reconcile global ao retornar ao foreground (Fase 3.6).
  static const Duration reconcileForegroundDebounce = Duration(seconds: 3);

  /// Versão atual do layout offline — incrementar ao migrar paths/schema.
  static const int offlineStorageVersion = 1;
}
