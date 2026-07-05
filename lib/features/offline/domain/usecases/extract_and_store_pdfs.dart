import '../../../../core/constants/offline_config.dart';
import '../ports/pdf_storage_port.dart';
import '../../data/datasources/zip_package_downloader.dart';
import '../../data/utils/zip_extraction_runner.dart';
import '../../data/utils/zip_pdf_extractor.dart';
import '../entities/offline_pdf_batch_item.dart';
import '../repositories/offline_pdf_repository.dart';

/// Intervalo de checkpoint intra-part durante extração/indexação bulk (backlog #2).
const _checkpointInterval = 50;

/// UC-09 — Extrair ZIP e gravar PDFs no store local (Fase 3.5).
///
/// Descompacta [zipPath] em isolate/compute → indexa em chunks Isar na main thread.
class ExtractAndStorePdfs {
  ExtractAndStorePdfs(this._repository, this._store, this._zipDownloader);

  final OfflinePdfRepository _repository;
  final PdfStoragePort _store;
  final ZipPackageDownloader _zipDownloader;

  Future<ExtractResult> call({
    required String zipPath,
    required List<String> expectedPdfIds,
    required String materialCategory,
    int startFromPdfIndex = 0,
    void Function(int extracted, int total)? onExtractProgress,
    void Function(int done, int total)? onProgress,
    Future<void> Function(int extractedPdfCount)? onProgressCheckpoint,
  }) async {
    final pendingIds = expectedPdfIds.skip(startFromPdfIndex).toList();
    final total = pendingIds.length;

    if (total == 0) {
      await _zipDownloader.deleteZip(zipPath);
      return ExtractResult(
        storedCount: 0,
        skippedCount: expectedPdfIds.length,
        totalInZip: expectedPdfIds.length,
        unmatchedPdfIds: const [],
        failedPdfIds: const [],
      );
    }

    final skipPdfIds = (await _repository.lookupBatch(
      pendingIds.toSet(),
    )).toList();

    final rootPath = await _store.rootPath;
    final extractResult = await runZipExtraction(
      params: ZipExtractParams(
        zipPath: zipPath,
        rootPath: rootPath,
        expectedPdfIds: pendingIds,
        skipPdfIds: skipPdfIds,
      ),
      zipDownloader: _zipDownloader,
      onExtractProgress: onExtractProgress,
    );

    final items = await persistExtractedItems(extractResult.items, _store);

    var storedCount = 0;
    final chunkSize = OfflineConfig.bulkIsarChunkSize;

    for (var i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;
      final chunk = items.sublist(i, end);
      await _repository.indexExtractedBatch(chunk);

      final prevProcessed = startFromPdfIndex + skipPdfIds.length + storedCount;
      storedCount += chunk.length;
      final newProcessed = startFromPdfIndex + skipPdfIds.length + storedCount;

      onProgress?.call(newProcessed, expectedPdfIds.length);

      await _emitProgressCheckpoints(
        prevProcessed: prevProcessed,
        newProcessed: newProcessed,
        onProgressCheckpoint: onProgressCheckpoint,
      );
    }

    await _zipDownloader.deleteZip(zipPath);

    onProgress?.call(expectedPdfIds.length, expectedPdfIds.length);

    return ExtractResult(
      storedCount: storedCount,
      skippedCount: skipPdfIds.length,
      totalInZip: expectedPdfIds.length,
      unmatchedPdfIds: extractResult.unmatchedEntries,
      failedPdfIds: extractResult.failedPdfIds,
    );
  }

  Future<void> _emitProgressCheckpoints({
    required int prevProcessed,
    required int newProcessed,
    required Future<void> Function(int extractedPdfCount)? onProgressCheckpoint,
  }) async {
    if (onProgressCheckpoint == null) return;

    var checkpointAt =
        ((prevProcessed ~/ _checkpointInterval) + 1) * _checkpointInterval;
    while (checkpointAt <= newProcessed) {
      await onProgressCheckpoint(checkpointAt);
      checkpointAt += _checkpointInterval;
    }
  }
}
