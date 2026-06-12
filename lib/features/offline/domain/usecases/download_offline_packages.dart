import 'package:dio/dio.dart';

import '../../../../core/constants/offline_config.dart';
import '../../data/datasources/disk_space_checker.dart';
import '../../data/datasources/offline_bulk_checkpoint_store.dart';
import '../../data/datasources/offline_manifest_remote_datasource.dart';
import '../../data/datasources/zip_package_downloader.dart';
import '../entities/offline_bulk_checkpoint.dart';
import '../entities/offline_download_progress.dart';
import '../entities/offline_manifest.dart';
import '../exceptions/offline_bulk_exceptions.dart';
import 'extract_and_store_pdfs.dart';
import 'reconcile_offline_index.dart';

/// UC-09 — Prefetch em lote por categoria (Fase 3.5).
///
/// Baixa ZIPs do offline-manifest em background; delega extração a
/// [ExtractAndStorePdfs]. Complementa cache on-demand [FetchAndStorePdf].
class DownloadOfflinePackages {
  DownloadOfflinePackages({
    required OfflineManifestRemoteDatasource manifestDatasource,
    required ZipPackageDownloader zipDownloader,
    required ExtractAndStorePdfs extractAndStorePdfs,
    required ReconcileOfflineIndex reconcileOfflineIndex,
    required DiskSpaceChecker diskSpaceChecker,
    required OfflineBulkCheckpointStore checkpointStore,
  })  : _manifestDatasource = manifestDatasource,
        _zipDownloader = zipDownloader,
        _extractAndStorePdfs = extractAndStorePdfs,
        _reconcileOfflineIndex = reconcileOfflineIndex,
        _diskSpaceChecker = diskSpaceChecker,
        _checkpointStore = checkpointStore;

  final OfflineManifestRemoteDatasource _manifestDatasource;
  final ZipPackageDownloader _zipDownloader;
  final ExtractAndStorePdfs _extractAndStorePdfs;
  final ReconcileOfflineIndex _reconcileOfflineIndex;
  final DiskSpaceChecker _diskSpaceChecker;
  final OfflineBulkCheckpointStore _checkpointStore;

  Future<void> call({
    required List<String> categories,
    void Function(OfflineDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
    OfflineBulkCheckpoint? resumeCheckpoint,
  }) async {
    if (categories.isEmpty) return;

    _ensureNotCancelled(cancelToken);

    final manifest = await _manifestDatasource.fetchManifest();
    await _ensureDiskSpace(manifest, categories);

    final checkpoint = resumeCheckpoint ??
        OfflineBulkCheckpoint(
          categories: List<String>.from(categories),
          categoryIndex: 0,
          partIndex: 0,
          extractedPdfCount: 0,
          startedAt: DateTime.now(),
        );

    await _checkpointStore.save(checkpoint);

    var donePdfsGlobal = _countDonePdfs(manifest, checkpoint);
    final totalPdfsGlobal = _countTotalPdfs(manifest, categories);

    for (var catIdx = checkpoint.categoryIndex;
        catIdx < checkpoint.categories.length;
        catIdx++) {
      _ensureNotCancelled(cancelToken);

      final materialCategory = checkpoint.categories[catIdx];
      final package = manifest.packageFor(materialCategory);
      if (package == null) continue;

      final startPartIdx =
          catIdx == checkpoint.categoryIndex ? checkpoint.partIndex : 0;

      for (var partIdx = startPartIdx;
          partIdx < package.parts.length;
          partIdx++) {
        _ensureNotCancelled(cancelToken);

        final part = package.parts[partIdx];
        final startPdfIdx = (catIdx == checkpoint.categoryIndex &&
                partIdx == checkpoint.partIndex)
            ? checkpoint.extractedPdfCount
            : 0;

        onProgress?.call(
          OfflineDownloadProgress(
            phase: OfflineDownloadPhase.fetching,
            currentCategory: materialCategory,
            categoryIndex: catIdx,
            totalCategories: categories.length,
            currentPart: partIdx + 1,
            totalParts: package.totalParts,
            donePdfs: donePdfsGlobal,
            totalPdfs: totalPdfsGlobal,
          ),
        );

        final zipPath = await _zipDownloader.download(
          url: part.url,
          filename: part.filename,
          cancelToken: cancelToken,
        );

        onProgress?.call(
          OfflineDownloadProgress(
            phase: OfflineDownloadPhase.extracting,
            currentCategory: materialCategory,
            categoryIndex: catIdx,
            totalCategories: categories.length,
            currentPart: partIdx + 1,
            totalParts: package.totalParts,
            donePdfs: donePdfsGlobal,
            totalPdfs: totalPdfsGlobal,
          ),
        );

        await _extractAndStorePdfs(
          zipPath: zipPath,
          expectedPdfIds: part.pdfs,
          materialCategory: materialCategory,
          startFromPdfIndex: startPdfIdx,
          onProgress: (done, total) {
            onProgress?.call(
              OfflineDownloadProgress(
                phase: OfflineDownloadPhase.storing,
                currentCategory: materialCategory,
                categoryIndex: catIdx,
                totalCategories: categories.length,
                currentPart: partIdx + 1,
                totalParts: package.totalParts,
                donePdfs: donePdfsGlobal + done,
                totalPdfs: totalPdfsGlobal,
              ),
            );
          },
        );

        donePdfsGlobal += part.pdfs.length - startPdfIdx;

        final nextCheckpoint = OfflineBulkCheckpoint(
          categories: checkpoint.categories,
          categoryIndex: catIdx,
          partIndex: partIdx + 1,
          extractedPdfCount: 0,
          startedAt: checkpoint.startedAt,
        );
        await _checkpointStore.save(nextCheckpoint);
      }

      onProgress?.call(
        OfflineDownloadProgress(
          phase: OfflineDownloadPhase.syncing,
          currentCategory: materialCategory,
          categoryIndex: catIdx,
          totalCategories: categories.length,
          currentPart: package.totalParts,
          totalParts: package.totalParts,
          donePdfs: donePdfsGlobal,
          totalPdfs: totalPdfsGlobal,
        ),
      );

      await _reconcileOfflineIndex(
        materialPackage: package,
        materialCategory: materialCategory,
      );

      await _checkpointStore.save(
        OfflineBulkCheckpoint(
          categories: checkpoint.categories,
          categoryIndex: catIdx + 1,
          partIndex: 0,
          extractedPdfCount: 0,
          startedAt: checkpoint.startedAt,
        ),
      );
    }

    await _checkpointStore.clear();
  }

  Future<void> _ensureDiskSpace(
    OfflineManifest manifest,
    List<String> categories,
  ) async {
    final requiredBytes = (manifest.totalSizeForCategories(categories) *
            OfflineConfig.diskSpaceSafetyMargin)
        .round();

    final freeBytes = await _diskSpaceChecker.getFreeBytes();
    if (freeBytes != null && freeBytes < requiredBytes) {
      throw InsufficientDiskSpaceException(
        requiredBytes: requiredBytes,
        availableBytes: freeBytes,
      );
    }
  }

  int _countTotalPdfs(OfflineManifest manifest, List<String> categories) {
    var total = 0;
    for (final category in categories) {
      total += manifest.packageFor(category)?.totalPdfs ?? 0;
    }
    return total;
  }

  int _countDonePdfs(
    OfflineManifest manifest,
    OfflineBulkCheckpoint checkpoint,
  ) {
    var done = 0;
    for (var i = 0; i < checkpoint.categoryIndex; i++) {
      final category = checkpoint.categories[i];
      done += manifest.packageFor(category)?.totalPdfs ?? 0;
    }

    if (checkpoint.categoryIndex < checkpoint.categories.length) {
      final package =
          manifest.packageFor(checkpoint.categories[checkpoint.categoryIndex]);
      if (package != null) {
        for (var p = 0;
            p < checkpoint.partIndex && p < package.parts.length;
            p++) {
          done += package.parts[p].pdfs.length;
        }
        if (checkpoint.partIndex < package.parts.length) {
          done += checkpoint.extractedPdfCount;
        }
      }
    }

    return done;
  }

  void _ensureNotCancelled(CancelToken? cancelToken) {
    if (cancelToken?.isCancelled == true) {
      throw const OfflineBulkCancelledException();
    }
  }
}
