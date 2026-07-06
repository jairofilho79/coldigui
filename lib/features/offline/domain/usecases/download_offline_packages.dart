import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../data/datasources/offline_bulk_checkpoint_store.dart';
import '../../data/datasources/offline_manifest_remote_datasource.dart';
import '../../data/datasources/zip_package_downloader.dart';
import '../entities/offline_bulk_checkpoint.dart';
import '../entities/offline_download_progress.dart';
import '../entities/offline_manifest.dart';
import '../entities/offline_pdf_batch_item.dart';
import '../exceptions/offline_bulk_exceptions.dart';
import 'extract_and_store_pdfs.dart';
import 'reconcile_offline_index.dart';

/// Resultado de [DownloadOfflinePackages.call].
class DownloadOfflinePackagesResult {
  const DownloadOfflinePackagesResult({
    this.unmatchedZipEntries = const [],
    this.failedPdfIds = const [],
  });

  final List<String> unmatchedZipEntries;
  final List<String> failedPdfIds;

  bool get hasWarnings =>
      unmatchedZipEntries.isNotEmpty || failedPdfIds.isNotEmpty;
}

/// UC-09 — Prefetch em lote por categoria (Fase 3.5).
///
/// Baixa ZIPs do offline-manifest em background; delega extração a
/// [ExtractAndStorePdfs]. Complementa cache on-demand [FetchAndStorePdf].
class DownloadOfflinePackages {
  DownloadOfflinePackages({
    required this._manifestDatasource,
    required this._zipDownloader,
    required this._extractAndStorePdfs,
    required this._reconcileOfflineIndex,
    required this._checkpointStore,
  });

  final OfflineManifestRemoteDatasource _manifestDatasource;
  final ZipPackageDownloader _zipDownloader;
  final ExtractAndStorePdfs _extractAndStorePdfs;
  final ReconcileOfflineIndex _reconcileOfflineIndex;
  final OfflineBulkCheckpointStore _checkpointStore;

  Future<DownloadOfflinePackagesResult> call({
    required List<String> categories,
    void Function(OfflineDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
    OfflineBulkCheckpoint? resumeCheckpoint,
  }) async {
    if (categories.isEmpty) {
      return const DownloadOfflinePackagesResult();
    }

    _ensureNotCancelled(cancelToken);

    final manifest = await _manifestDatasource.fetchManifest();

    final checkpoint =
        resumeCheckpoint ??
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
    final unmatchedAccumulator = <String>[];
    final failedPdfIdsAccumulator = <String>[];

    for (
      var catIdx = checkpoint.categoryIndex;
      catIdx < checkpoint.categories.length;
      catIdx++
    ) {
      _ensureNotCancelled(cancelToken);

      final materialCategory = checkpoint.categories[catIdx];
      final package = manifest.packageFor(materialCategory);
      if (package == null) continue;

      final startPartIdx = catIdx == checkpoint.categoryIndex
          ? checkpoint.partIndex
          : 0;

      for (
        var partIdx = startPartIdx;
        partIdx < package.parts.length;
        partIdx++
      ) {
        _ensureNotCancelled(cancelToken);

        final part = package.parts[partIdx];
        final startPdfIdx =
            (catIdx == checkpoint.categoryIndex &&
                partIdx == checkpoint.partIndex)
            ? checkpoint.extractedPdfCount
            : 0;

        if (!kIsWeb) {
          onProgress?.call(
            _buildProgress(
              phase: OfflineDownloadPhase.fetching,
              materialCategory: materialCategory,
              catIdx: catIdx,
              categoriesLength: categories.length,
              partIdx: partIdx + 1,
              totalParts: package.totalParts,
              donePdfs: donePdfsGlobal,
              totalPdfs: totalPdfsGlobal,
            ),
          );
        }

        final zipPath = await _downloadZip(
          url: part.url,
          filename: part.filename,
          expectedSize: part.size,
          cancelToken: cancelToken,
          onReceiveProgress: kIsWeb
              ? null
              : (received, total) {
                  onProgress?.call(
                    _buildProgress(
                      phase: OfflineDownloadPhase.fetching,
                      materialCategory: materialCategory,
                      catIdx: catIdx,
                      categoriesLength: categories.length,
                      partIdx: partIdx + 1,
                      totalParts: package.totalParts,
                      donePdfs: donePdfsGlobal,
                      totalPdfs: totalPdfsGlobal,
                      zipBytesReceived: received,
                      zipBytesTotal: total > 0 ? total : part.size,
                    ),
                  );
                },
        );

        if (!kIsWeb) {
          onProgress?.call(
            _buildProgress(
              phase: OfflineDownloadPhase.extracting,
              materialCategory: materialCategory,
              catIdx: catIdx,
              categoriesLength: categories.length,
              partIdx: partIdx + 1,
              totalParts: package.totalParts,
              donePdfs: donePdfsGlobal,
              totalPdfs: totalPdfsGlobal,
            ),
          );
        }

        final extractResult = await _extractPdfs(
          zipPath: zipPath,
          expectedPdfIds: part.pdfs,
          materialCategory: materialCategory,
          startFromPdfIndex: startPdfIdx,
          cancelToken: cancelToken,
          onExtractProgress: (extracted, total) {
            onProgress?.call(
              _buildProgress(
                phase: OfflineDownloadPhase.extracting,
                materialCategory: materialCategory,
                catIdx: catIdx,
                categoriesLength: categories.length,
                partIdx: partIdx + 1,
                totalParts: package.totalParts,
                donePdfs: donePdfsGlobal + startPdfIdx + extracted,
                totalPdfs: totalPdfsGlobal,
              ),
            );
          },
          onProgress: (done, total) {
            onProgress?.call(
              _buildProgress(
                phase: OfflineDownloadPhase.storing,
                materialCategory: materialCategory,
                catIdx: catIdx,
                categoriesLength: categories.length,
                partIdx: partIdx + 1,
                totalParts: package.totalParts,
                donePdfs: donePdfsGlobal + done,
                totalPdfs: totalPdfsGlobal,
              ),
            );
          },
          onProgressCheckpoint: (count) => _checkpointStore.save(
            OfflineBulkCheckpoint(
              categories: checkpoint.categories,
              categoryIndex: catIdx,
              partIndex: partIdx,
              extractedPdfCount: count,
              startedAt: checkpoint.startedAt,
            ),
          ),
        );

        if (extractResult.unmatchedPdfIds.isNotEmpty) {
          developer.log(
            'Part ${part.filename}: ${extractResult.unmatchedPdfIds.length} '
            'entries no ZIP sem correspondência no manifest: '
            '${extractResult.unmatchedPdfIds.take(5).toList()}',
            name: 'DownloadOfflinePackages',
            level: 900,
          );
          unmatchedAccumulator.addAll(extractResult.unmatchedPdfIds);
        }

        if (extractResult.failedPdfIds.isNotEmpty) {
          developer.log(
            'Part ${part.filename}: ${extractResult.failedPdfIds.length} '
            'PDFs esperados falharam na extração: '
            '${extractResult.failedPdfIds.take(5).toList()}',
            name: 'DownloadOfflinePackages',
            level: 900,
          );
          failedPdfIdsAccumulator.addAll(extractResult.failedPdfIds);
        }

        final processedInPart =
            extractResult.storedCount + extractResult.skippedCount;
        final expectedInPart = part.pdfs.length - startPdfIdx;
        if (processedInPart != expectedInPart) {
          developer.log(
            'Part ${part.filename}: esperados $expectedInPart PDFs, '
            'processados $processedInPart '
            '(stored=${extractResult.storedCount}, '
            'skipped=${extractResult.skippedCount}, '
            'failed=${extractResult.failedPdfIds.length})',
            name: 'DownloadOfflinePackages',
            level: 900,
          );
        }

        donePdfsGlobal += processedInPart;

        final nextCheckpoint = OfflineBulkCheckpoint(
          categories: checkpoint.categories,
          categoryIndex: catIdx,
          partIndex: partIdx + 1,
          extractedPdfCount: 0,
          startedAt: checkpoint.startedAt,
        );
        await _checkpointStore.save(nextCheckpoint);
      }

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

    if (categories.isNotEmpty) {
      final lastCategory = checkpoint.categories.last;
      final lastPackage = manifest.packageFor(lastCategory);

      onProgress?.call(
        _buildProgress(
          phase: OfflineDownloadPhase.syncing,
          materialCategory: lastCategory,
          catIdx: checkpoint.categories.length - 1,
          categoriesLength: categories.length,
          partIdx: lastPackage?.totalParts ?? 0,
          totalParts: lastPackage?.totalParts ?? 0,
          donePdfs: donePdfsGlobal,
          totalPdfs: totalPdfsGlobal,
        ),
      );

      await _reconcileOfflineIndex();
    }

    await _checkpointStore.clear();

    return DownloadOfflinePackagesResult(
      unmatchedZipEntries: unmatchedAccumulator,
      failedPdfIds: failedPdfIdsAccumulator,
    );
  }

  Future<String> _downloadZip({
    required String url,
    required String filename,
    required int expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    try {
      return await _zipDownloader.download(
        url: url,
        filename: filename,
        expectedSize: expectedSize,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on FileSystemException catch (e) {
      if (_isEnospc(e)) {
        throw const InsufficientDiskSpaceException(
          requiredBytes: -1,
          availableBytes: 0,
        );
      }
      rethrow;
    }
  }

  Future<ExtractResult> _extractPdfs({
    required String zipPath,
    required List<String> expectedPdfIds,
    required String materialCategory,
    required int startFromPdfIndex,
    CancelToken? cancelToken,
    void Function(int extracted, int total)? onExtractProgress,
    void Function(int done, int total)? onProgress,
    Future<void> Function(int extractedPdfCount)? onProgressCheckpoint,
  }) async {
    try {
      return await _extractAndStorePdfs(
        zipPath: zipPath,
        expectedPdfIds: expectedPdfIds,
        materialCategory: materialCategory,
        startFromPdfIndex: startFromPdfIndex,
        cancelToken: cancelToken,
        onExtractProgress: onExtractProgress,
        onProgress: onProgress,
        onProgressCheckpoint: onProgressCheckpoint,
      );
    } on FileSystemException catch (e) {
      if (_isEnospc(e)) {
        throw const InsufficientDiskSpaceException(
          requiredBytes: -1,
          availableBytes: 0,
        );
      }
      rethrow;
    }
  }

  bool _isEnospc(FileSystemException e) => e.osError?.errorCode == 28;

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
      final package = manifest.packageFor(
        checkpoint.categories[checkpoint.categoryIndex],
      );
      if (package != null) {
        for (
          var p = 0;
          p < checkpoint.partIndex && p < package.parts.length;
          p++
        ) {
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

  OfflineDownloadProgress _buildProgress({
    required OfflineDownloadPhase phase,
    required String materialCategory,
    required int catIdx,
    required int categoriesLength,
    required int partIdx,
    required int totalParts,
    required int donePdfs,
    required int totalPdfs,
    int? zipBytesReceived,
    int? zipBytesTotal,
  }) {
    if (kIsWeb) {
      final webPhase = phase == OfflineDownloadPhase.syncing
          ? OfflineDownloadPhase.syncing
          : OfflineDownloadPhase.fetching;
      return OfflineDownloadProgress(
        phase: webPhase,
        currentCategory: materialCategory,
        categoryIndex: catIdx,
        totalCategories: categoriesLength,
        currentPart: 0,
        totalParts: 0,
        donePdfs: donePdfs,
        totalPdfs: totalPdfs,
      );
    }

    return OfflineDownloadProgress(
      phase: phase,
      currentCategory: materialCategory,
      categoryIndex: catIdx,
      totalCategories: categoriesLength,
      currentPart: partIdx,
      totalParts: totalParts,
      donePdfs: donePdfs,
      totalPdfs: totalPdfs,
      zipBytesReceived: zipBytesReceived,
      zipBytesTotal: zipBytesTotal,
    );
  }
}
