import 'dart:math' show min;

import '../../../../core/constants/offline_config.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../datasources/zip_package_downloader.dart';
import '../../domain/entities/offline_pdf_batch_item.dart';
import '../../domain/ports/pdf_storage_port.dart';
import 'pdf_integrity_validator.dart';
import 'zip_pdf_extractor_types.dart';

Future<ZipExtractResult> runZipExtraction({
  required ZipExtractParams params,
  required ZipPackageDownloader zipDownloader,
  void Function(int extracted, int total)? onExtractProgress,
}) async {
  final skipSet = params.skipPdfIds.toSet();
  final idsToFetch = [
    for (final pdfId in params.expectedPdfIds)
      if (!skipSet.contains(pdfId)) pdfId,
  ];

  final items = <ExtractedPdfItem>[];
  final failedPdfIds = <String>[];
  var extracted = 0;
  var nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      if (nextIndex >= idsToFetch.length) break;
      final index = nextIndex++;
      final pdfId = idsToFetch[index];

      try {
        final bytes = await zipDownloader.fetchPdfBytes(pdfId);
        if (bytes.isEmpty ||
            !PdfIntegrityValidator.hasValidPdfMagicBytes(
              bytes.length >= 4 ? bytes.sublist(0, 4) : bytes,
            )) {
          failedPdfIds.add(pdfId);
        } else {
          items.add(
            ExtractedPdfItem(
              pdfId: pdfId,
              absolutePath: '',
              fileSize: bytes.length,
              contentBytes: bytes,
            ),
          );
        }
      } on Object {
        failedPdfIds.add(pdfId);
      }

      extracted++;
      onExtractProgress?.call(extracted, params.expectedPdfIds.length);
    }
  }

  final workerCount = min(
    OfflineConfig.bulkWebFetchConcurrency,
    idsToFetch.length,
  );
  if (workerCount > 0) {
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  return ZipExtractResult(
    items: items,
    unmatchedEntries: const [],
    failedPdfIds: failedPdfIds,
  );
}

Future<PersistExtractedOutcome> persistExtractedItems(
  List<ExtractedPdfItem> items,
  PdfStoragePort store,
) async {
  final persisted = <ExtractedPdfItem>[];
  final failedPdfIds = <String>[];

  for (final item in items) {
    final bytes = item.contentBytes;
    if (bytes == null) {
      failedPdfIds.add(item.pdfId);
      continue;
    }

    var relPath = PdfPathNormalizer.getPdfRelPath(item.pdfId);
    if (relPath.startsWith('assets/')) {
      relPath = relPath.substring('assets/'.length);
    }

    try {
      final storageKey = await store.writeAtomic(bytes, relPath);
      persisted.add(
        ExtractedPdfItem(
          pdfId: item.pdfId,
          absolutePath: storageKey,
          fileSize: bytes.length,
        ),
      );
    } on Object {
      failedPdfIds.add(item.pdfId);
    }
  }

  return PersistExtractedOutcome(items: persisted, failedPdfIds: failedPdfIds);
}
