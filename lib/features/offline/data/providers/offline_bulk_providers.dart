import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../domain/usecases/download_offline_packages.dart';
import '../../domain/usecases/extract_and_store_pdfs.dart';
import '../datasources/zip_package_downloader.dart';
import 'offline_core_providers.dart';

/// DI — download de ZIPs transitórios (UC-09 bulk).
///
/// A limpeza de `.tmp` órfãos roda no início de cada `download()`, com o
/// parcial em curso e o do checkpoint ativo preservados (spec C.2) — fazê-la
/// aqui apagaria às cegas o parcial de um download já em andamento.
final zipPackageDownloaderProvider = Provider<ZipPackageDownloader>((ref) {
  return ZipPackageDownloader(
    ref.watch(dioProvider),
    ref.watch(pdfStoragePortProvider),
  );
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
