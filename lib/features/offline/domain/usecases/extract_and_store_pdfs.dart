import 'package:flutter/foundation.dart';

import '../../../../core/constants/offline_config.dart';
import '../../data/datasources/pdf_local_store.dart';
import '../../data/datasources/zip_package_downloader.dart';
import '../../data/utils/zip_pdf_extractor.dart';
import '../entities/offline_pdf_batch_item.dart';
import '../repositories/offline_pdf_repository.dart';

/// UC-09 — Extrair ZIP e gravar PDFs no store local (Fase 3.5).
///
/// Descompacta [zipPath] em isolate → indexa em chunks Isar no isolate principal.
class ExtractAndStorePdfs {
  ExtractAndStorePdfs(
    this._repository,
    this._store,
    this._zipDownloader,
  );

  final OfflinePdfRepository _repository;
  final PdfLocalStore _store;
  final ZipPackageDownloader _zipDownloader;

  Future<ExtractResult> call({
    required String zipPath,
    required List<String> expectedPdfIds,
    required String materialCategory,
    int startFromPdfIndex = 0,
    void Function(int done, int total)? onProgress,
  }) async {
    final pendingIds = expectedPdfIds.skip(startFromPdfIndex).toList();
    final total = pendingIds.length;

    if (total == 0) {
      await _zipDownloader.deleteZip(zipPath);
      return ExtractResult(
        storedCount: 0,
        skippedCount: expectedPdfIds.length,
        totalInZip: expectedPdfIds.length,
      );
    }

    final skipPdfIds =
        (await _repository.lookupBatch(pendingIds.toSet())).toList();

    final root = await _store.rootDirectory;
    final extractResult = await compute(
      extractZipPdfs,
      ZipExtractParams(
        zipPath: zipPath,
        rootPath: root.path,
        expectedPdfIds: pendingIds,
        skipPdfIds: skipPdfIds,
      ),
    );

    var storedCount = 0;
    final chunkSize = OfflineConfig.bulkIsarChunkSize;
    final items = extractResult.items;

    for (var i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;
      final chunk = items.sublist(i, end);
      await _repository.indexExtractedBatch(chunk);
      storedCount += chunk.length;
      onProgress?.call(
        startFromPdfIndex + skipPdfIds.length + storedCount,
        expectedPdfIds.length,
      );
    }

    await _zipDownloader.deleteZip(zipPath);

    onProgress?.call(expectedPdfIds.length, expectedPdfIds.length);

    return ExtractResult(
      storedCount: storedCount,
      skippedCount: skipPdfIds.length,
      totalInZip: expectedPdfIds.length,
    );
  }
}
