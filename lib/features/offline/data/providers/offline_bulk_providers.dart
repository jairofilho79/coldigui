import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../domain/usecases/download_offline_packages.dart';
import '../../domain/usecases/extract_and_store_pdfs.dart';
import '../datasources/zip_package_downloader.dart';
import 'offline_core_providers.dart';

/// DI — download de ZIPs transitórios (UC-09 bulk).
final zipPackageDownloaderProvider = Provider<ZipPackageDownloader>((ref) {
  final downloader = ZipPackageDownloader(
    ref.watch(dioProvider),
    ref.watch(pdfStoragePortProvider),
  );
  unawaited(downloader.cleanOrphanedTempFiles());
  return downloader;
});

/// DI — [ExtractAndStorePdfs] (Fase 3.5) — puxa `package:archive` via extractors.
final extractAndStorePdfsProvider = Provider<ExtractAndStorePdfs>((ref) {
  return ExtractAndStorePdfs(
    ref.watch(offlinePdfRepositoryProvider),
    ref.watch(pdfStoragePortProvider),
    ref.watch(zipPackageDownloaderProvider),
  );
});

/// DI — [DownloadOfflinePackages] (Fase 3.5).
final downloadOfflinePackagesProvider = Provider<DownloadOfflinePackages>((
  ref,
) {
  return DownloadOfflinePackages(
    manifestDatasource: ref.watch(offlineManifestRemoteDatasourceProvider),
    zipDownloader: ref.watch(zipPackageDownloaderProvider),
    extractAndStorePdfs: ref.watch(extractAndStorePdfsProvider),
    reconcileOfflineIndex: ref.watch(reconcileOfflineIndexProvider),
    checkpointStore: ref.watch(offlineBulkCheckpointStoreProvider),
  );
});
