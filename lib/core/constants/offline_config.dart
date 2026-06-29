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

  /// Base do backoff exponencial entre tentativas de fetch on-demand (Fase 3.3).
  ///
  /// Delay efetivo: `retryBackoffBase * 2^(attempt-1) * (1 + jitter)` com
  /// jitter até 30% e teto [maxRetryDelay] (≈500ms, ≈1s nas 2 primeiras esperas).
  static const Duration retryBackoffBase = Duration(milliseconds: 500);

  /// Teto do backoff exponencial com jitter em [FetchAndStorePdf].
  static const Duration maxRetryDelay = Duration(seconds: 30);

  /// Timeout de recepção por request em [PdfBytesDatasource._fetchRemote].
  ///
  /// Independente do timeout global do Dio (PDFs podem levar mais de 30s).
  static const Duration pdfDownloadReceiveTimeout = Duration(seconds: 120);

  /// Timeout de envio por request em [PdfBytesDatasource._fetchRemote].
  static const Duration pdfDownloadSendTimeout = Duration(seconds: 10);

  /// Watchdog inter-chunk para download de ZIP bulk (UC-09).
  ///
  /// `Duration.zero` = sem limite (recomendado para arquivos grandes).
  static const Duration zipDownloadReceiveTimeout = Duration.zero;

  /// Timeout de conexão por request em [ZipPackageDownloader.download].
  static const Duration zipDownloadConnectTimeout = Duration(seconds: 60);

  /// Timeout de envio por request em [ZipPackageDownloader.download].
  static const Duration zipDownloadSendTimeout = Duration(seconds: 30);

  /// Tamanho de chunk para upsert Isar no bulk UC-09 (Fase 3.5).
  static const int bulkIsarChunkSize = 75;

  /// Subpasta transitória de ZIPs bulk sob `plpcg_pdfs/`.
  static const String zipTempSubdir = '_bulk_zips';

  /// Quota padrão do cache on-demand de PDFs (LRU eviction — backlog #10).
  static const int defaultPdfCacheQuotaBytes = 500 * 1024 * 1024;

  /// Debounce antes de reconcile global ao retornar ao foreground (Fase 3.6).
  static const Duration reconcileForegroundDebounce = Duration(seconds: 3);

  /// Intervalo mínimo entre polls de checksum do manifest ao foreground (UC-12).
  static const Duration catalogChecksumPollMinInterval = Duration(minutes: 30);

  /// Intervalo mínimo entre reconciles globais (backlog #12).
  static const Duration reconcileMinInterval = Duration(minutes: 30);

  /// Versão atual do layout offline — incrementar ao migrar paths/schema.
  static const int offlineStorageVersion = 2;
}
