import 'dart:math' show min;

import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../data/datasources/offline_manifest_remote_datasource.dart';
import '../../data/utils/pdf_integrity_validator.dart';
import '../entities/offline_manifest.dart';
import '../entities/offline_pdf_entry.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/offline_category_resolver.dart';
import 'fetch_and_store_pdf.dart';

/// Resultado de [DownloadMissingPdfs] (UC-10, Fase 3.6/3.7 UI).
class DownloadMissingResult {
  const DownloadMissingResult({
    required this.downloadedCount,
    required this.skippedCount,
    required this.failedCount,
  });

  /// PDFs baixados e indexados nesta execução.
  final int downloadedCount;

  /// PDFs já no índice — não re-fetchados.
  final int skippedCount;

  /// Falhas de fetch/upsert.
  final int failedCount;
}

/// Limite de downloads on-demand simultâneos (UC-10, backlog #10).
const _maxConcurrentDownloads = 3;

/// UC-10 — Baixar PDFs faltantes no índice (Fase 3.6).
///
/// Pré-filtra PDFs válidos (índice + arquivo no disco) e faz fetch **somente**
/// dos ausentes no manifest. [onProgress] reporta `done/total` onde `total` é
/// a quantidade de faltantes, não o tamanho total do manifest.
class DownloadMissingPdfs {
  DownloadMissingPdfs(
    this._manifestDatasource,
    this._repository,
    this._fetchAndStorePdf,
  );

  final OfflineManifestRemoteDatasource _manifestDatasource;
  final OfflinePdfRepository _repository;
  final FetchAndStorePdf _fetchAndStorePdf;

  Future<DownloadMissingResult> call({
    Set<String>? materialCategories,

    /// Chamado após cada fetch (ou falha). [total] = quantidade de faltantes.
    void Function(int done, int total)? onProgress,
  }) async {
    final manifest = await _manifestDatasource.fetchManifest();
    final categories = materialCategories ?? manifest.packages.keys.toSet();
    final allPdfIds = _collectPdfIds(manifest, categories);
    final validPdfIds = await _collectValidPdfIds();
    final missingPdfIds = [
      for (final pdfId in allPdfIds)
        if (!validPdfIds.contains(pdfId)) pdfId,
    ];

    var downloaded = 0;
    var failed = 0;

    onProgress?.call(0, missingPdfIds.length);

    if (missingPdfIds.isNotEmpty) {
      var completed = 0;
      var nextIndex = 0;

      Future<void> worker() async {
        while (true) {
          if (nextIndex >= missingPdfIds.length) break;
          final index = nextIndex++;
          final pdfId = missingPdfIds[index];

          try {
            await _fetchAndStorePdf(
              pdfId: pdfId,
              remotePath: _remotePathFromPdfId(pdfId),
              category: OfflineCategoryResolver.fromPdfId(pdfId),
            );
            downloaded++;
          } on Object {
            failed++;
          }

          completed++;
          onProgress?.call(completed, missingPdfIds.length);
        }
      }

      final workerCount = min(_maxConcurrentDownloads, missingPdfIds.length);
      await Future.wait(List.generate(workerCount, (_) => worker()));
    }

    return DownloadMissingResult(
      downloadedCount: downloaded,
      skippedCount: allPdfIds.length - missingPdfIds.length,
      failedCount: failed,
    );
  }

  /// PDFs com índice Isar e arquivo válido no disco — uma passagem no índice.
  Future<Set<String>> _collectValidPdfIds() async {
    final entries = await _repository.listAll();
    final validPdfIds = <String>{};

    const batchSize = 50;
    for (var i = 0; i < entries.length; i += batchSize) {
      final batch = entries.sublist(i, min(i + batchSize, entries.length));
      final results = await Future.wait(batch.map(_hasValidFile));
      for (var j = 0; j < batch.length; j++) {
        if (results[j]) validPdfIds.add(batch[j].pdfId);
      }
    }

    return validPdfIds;
  }

  Future<bool> _hasValidFile(OfflinePdfEntry entry) =>
      PdfIntegrityValidator.isValidPdfFile(entry.absolutePath);

  List<String> _collectPdfIds(
    OfflineManifest manifest,
    Set<String> categories,
  ) {
    final ids = <String>[];
    for (final category in categories) {
      final package = manifest.packages[category];
      if (package == null) continue;
      for (final part in package.parts) {
        ids.addAll(part.pdfs);
      }
    }
    return ids;
  }

  static String _remotePathFromPdfId(String pdfId) {
    var relPath = PdfPathNormalizer.getPdfRelPath(pdfId);
    if (!relPath.startsWith('assets/')) {
      relPath = 'assets/$relPath';
    }
    return '/$relPath';
  }
}
