import 'package:flutter/foundation.dart' show kIsWeb;

/// Limites e retry do store offline nativo (Fase 3).
///
/// [pdfStorageSubdir] — subpasta em ApplicationDocumentsDirectory (perene).
/// Constantes `sw*` e [pdfCacheName] são legado PWA — revisar na 3.1.
abstract final class OfflineConfig {
  /// Subdiretório de PDFs offline em documents — **não** usar cache/temp.
  static const String pdfStorageSubdir = 'plpcg_pdfs';
  static const String pdfCacheName = 'plpc-pdfs';
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

  /// Tamanho de chunk para upsert Isar no bulk UC-09 (Fase 3.5).
  static const int bulkIsarChunkSize = 75;

  /// Nome do bucket Cache API para PDFs offline na web (Solução C).
  ///
  /// Distinto de [pdfCacheName] (legado Service Worker — não alterar).
  static const String pdfCacheStoreName = 'plpcg-pdfs-store-v1';

  /// Quota padrão do cache on-demand de PDFs (LRU eviction — backlog #10).
  static const int defaultPdfCacheQuotaBytes = 500 * 1024 * 1024;

  /// Debounce antes de reconcile global ao retornar ao foreground (Fase 3.6).
  static const Duration reconcileForegroundDebounce = Duration(seconds: 3);

  /// Intervalo mínimo entre reconciles globais (backlog #12).
  static const Duration reconcileMinInterval = Duration(minutes: 30);

  /// Versão atual do layout offline — incrementar ao migrar paths/schema.
  static const int offlineStorageVersion = 5;

  /// Intervalo mínimo entre syncs do catálogo Coldigom ao voltar ao
  /// foreground (O5).
  static const Duration coldigomCatalogSyncMinInterval = Duration(minutes: 30);

  /// Praises convertidos por fatia na hidratação do catálogo Coldigom; entre
  /// fatias o event loop é cedido para não travar o primeiro frame na web.
  static const int coldigomHydrationChunkSize = 300;

  /// Subdiretório de áudios Coldigom baixados em documents (nativo).
  static const String audioStorageSubdir = 'plpcg_audio';

  /// Bucket Cache API dos áudios Coldigom na web — irmão de
  /// [pdfCacheStoreName]; buckets separados para «Remover áudios» não
  /// tocar nos PDFs.
  static const String audioCacheStoreName = 'plpcg-audio-store-v1';

  /// Downloads Coldigom simultâneos (spec offline Coldigom §5.2): 3 no
  /// nativo (como o on-demand de PDF), 6 na web.
  static int get coldigomDownloadConcurrency => kIsWeb ? 6 : 3;

  /// Estimativa de bytes por `type` quando o dump não traz `size` (O13).
  static const Map<String, int> coldigomEstimatedBytesByType = {
    'pdf': 350 * 1024,
    'mp3': 4 * 1024 * 1024,
    'audio': 4 * 1024 * 1024,
    'chord': 1024,
    'gestures': 60 * 1024,
  };
}
