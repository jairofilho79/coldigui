import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../catalog/data/providers/catalog_providers.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../domain/repositories/offline_pdf_repository.dart';
import '../../../pdf_opening/domain/usecases/validate_pdf_availability.dart';
import '../../domain/usecases/download_offline_packages.dart';
import '../../domain/usecases/extract_and_store_pdfs.dart';
import '../../domain/usecases/fetch_and_store_pdf.dart';
import '../../domain/usecases/get_offline_stats_by_category.dart';
import '../../domain/usecases/clear_offline_cache.dart';
import '../../domain/usecases/download_missing_pdfs.dart';
import '../../domain/usecases/migrate_offline_storage.dart';
import '../../domain/usecases/reconcile_offline_index.dart';
import '../../domain/usecases/resolve_pdf_for_reader.dart';
import '../../../playlists/data/providers/playlist_providers.dart';
import '../datasources/disk_space_checker.dart';
import '../datasources/favorite_pdf_ids_resolver.dart';
import '../datasources/offline_available_store.dart';
import '../datasources/offline_bulk_checkpoint_store.dart';
import '../datasources/offline_manifest_remote_datasource.dart';
import '../datasources/offline_pdf_local_datasource.dart';
import '../datasources/pdf_local_store.dart';
import '../datasources/zip_package_downloader.dart';
import '../repositories/offline_pdf_repository_impl.dart';

/// DI — [PdfLocalStore] em `ApplicationDocumentsDirectory/plpcg_pdfs/`.
final pdfLocalStoreProvider = Provider<PdfLocalStore>((ref) {
  return PdfLocalStore();
});

/// DI — CRUD Isar [OfflinePdfIndex] via [isarProvider].
final offlinePdfLocalDatasourceProvider =
    Provider<OfflinePdfLocalDatasource>((ref) {
  return OfflinePdfLocalDatasource(ref.watch(isarProvider));
});

/// DI — [OfflinePdfRepositoryImpl]; ponto de entrada para use cases 3.2+.
final offlinePdfRepositoryProvider = Provider<OfflinePdfRepository>((ref) {
  return OfflinePdfRepositoryImpl(
    store: ref.watch(pdfLocalStoreProvider),
    local: ref.watch(offlinePdfLocalDatasourceProvider),
  );
});

/// DI — [FetchAndStorePdf] (Fase 3.3).
///
/// Compõe [pdfBytesDatasourceProvider] (UC-04) + [offlinePdfRepositoryProvider].
/// Usado por [resolvePdfForReaderProvider] e futuramente por [DownloadMissingPdfs].
final fetchAndStorePdfProvider = Provider<FetchAndStorePdf>((ref) {
  return FetchAndStorePdf(
    ref.watch(pdfBytesDatasourceProvider),
    ref.watch(offlinePdfRepositoryProvider),
    diskSpaceChecker: ref.watch(diskSpaceCheckerProvider),
    favoritePdfIdsResolver: ref.watch(favoritePdfIdsResolverProvider),
  );
});

/// DI — [ResolvePdfForReader] (Fase 3.2 + 3.3 + 3.4).
///
/// Consumido por [LouvorCard] antes de abrir/compartilhar/salvar PDF.
final resolvePdfForReaderProvider = Provider<ResolvePdfForReader>((ref) {
  final offlineStore = ref.watch(offlineAvailableStoreProvider);
  return ResolvePdfForReader(
    ref.watch(offlinePdfRepositoryProvider),
    ref.watch(fetchAndStorePdfProvider),
    isFullOfflineMode: () => offlineStore.isConfigured,
  );
});

/// DI — [ValidatePdfAvailability] (Fase 3.4).
///
/// Provider aqui evita ciclo com [pdf_opening_providers].
final validatePdfAvailabilityProvider =
    Provider<ValidatePdfAvailability>((ref) {
  return ValidatePdfAvailability(ref.watch(offlinePdfRepositoryProvider));
});

/// DI — manifest remoto de pacotes offline (UC-09).
final offlineManifestRemoteDatasourceProvider =
    Provider<OfflineManifestRemoteDatasource>((ref) {
  return OfflineManifestRemoteDatasource(ref.watch(dioProvider));
});

/// DI — checagem de espaço livre em disco.
final diskSpaceCheckerProvider = Provider<DiskSpaceChecker>((ref) {
  return DiskSpaceChecker();
});

/// DI — PDFs em playlists favoritas (protegidos da eviction LRU).
final favoritePdfIdsResolverProvider = Provider<FavoritePdfIdsResolver>((ref) {
  return FavoritePdfIdsResolver(ref.watch(playlistLocalDatasourceProvider));
});

/// DI — download de ZIPs transitórios.
final zipPackageDownloaderProvider = Provider<ZipPackageDownloader>((ref) {
  final downloader = ZipPackageDownloader(
    ref.watch(dioProvider),
    ref.watch(pdfLocalStoreProvider),
  );
  unawaited(downloader.cleanOrphanedTempFiles());
  return downloader;
});

/// DI — checkpoint de resume bulk.
final offlineBulkCheckpointStoreProvider =
    Provider<OfflineBulkCheckpointStore>((ref) {
  return OfflineBulkCheckpointStore(ref.watch(sharedPreferencesProvider));
});

/// DI — flag UC-09/UC-10 [StorageKeys.offlineAvailable] (`TRUE`/`FALSE`).
final offlineAvailableStoreProvider = Provider<OfflineAvailableStore>((ref) {
  return OfflineAvailableStore(ref.watch(sharedPreferencesProvider));
});

/// DI — [ExtractAndStorePdfs] (Fase 3.5).
final extractAndStorePdfsProvider = Provider<ExtractAndStorePdfs>((ref) {
  return ExtractAndStorePdfs(
    ref.watch(offlinePdfRepositoryProvider),
    ref.watch(pdfLocalStoreProvider),
    ref.watch(zipPackageDownloaderProvider),
  );
});

/// DI — [ReconcileOfflineIndex] mínimo (Fase 3.5).
final reconcileOfflineIndexProvider = Provider<ReconcileOfflineIndex>((ref) {
  return ReconcileOfflineIndex(
    ref.watch(offlinePdfRepositoryProvider),
    ref.watch(pdfLocalStoreProvider),
  );
});

/// DI — [DownloadOfflinePackages] (Fase 3.5).
final downloadOfflinePackagesProvider =
    Provider<DownloadOfflinePackages>((ref) {
  return DownloadOfflinePackages(
    manifestDatasource: ref.watch(offlineManifestRemoteDatasourceProvider),
    zipDownloader: ref.watch(zipPackageDownloaderProvider),
    extractAndStorePdfs: ref.watch(extractAndStorePdfsProvider),
    reconcileOfflineIndex: ref.watch(reconcileOfflineIndexProvider),
    diskSpaceChecker: ref.watch(diskSpaceCheckerProvider),
    checkpointStore: ref.watch(offlineBulkCheckpointStoreProvider),
  );
});

/// DI — [GetOfflineStatsByCategory] (Fase 3.6).
final getOfflineStatsByCategoryProvider =
    Provider<GetOfflineStatsByCategory>((ref) {
  return GetOfflineStatsByCategory(
    ref.watch(offlinePdfRepositoryProvider),
    ref.watch(catalogLocalDatasourceProvider),
    ref.watch(offlineManifestRemoteDatasourceProvider),
    ref.watch(pdfLocalStoreProvider),
  );
});

/// DI — [DownloadMissingPdfs] (Fase 3.6).
final downloadMissingPdfsProvider = Provider<DownloadMissingPdfs>((ref) {
  return DownloadMissingPdfs(
    ref.watch(offlineManifestRemoteDatasourceProvider),
    ref.watch(offlinePdfRepositoryProvider),
    ref.watch(fetchAndStorePdfProvider),
  );
});

/// DI — [ClearOfflineCache] (Fase 3.6).
final clearOfflineCacheProvider = Provider<ClearOfflineCache>((ref) {
  return ClearOfflineCache(
    ref.watch(offlinePdfRepositoryProvider),
    ref.watch(pdfLocalStoreProvider),
    ref.watch(offlineBulkCheckpointStoreProvider),
    ref.watch(offlineAvailableStoreProvider),
  );
});

/// DI — [MigrateOfflineStorage] (Fase 3.6).
final migrateOfflineStorageProvider = Provider<MigrateOfflineStorage>((ref) {
  return MigrateOfflineStorage(ref.watch(sharedPreferencesProvider));
});
