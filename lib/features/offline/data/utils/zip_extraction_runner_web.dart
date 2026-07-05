import 'package:flutter/foundation.dart';

import '../../../../core/utils/pdf_path_normalizer.dart';
import '../datasources/zip_package_downloader.dart';
import '../../domain/entities/offline_pdf_batch_item.dart';
import '../../domain/ports/pdf_storage_port.dart';
import 'zip_pdf_extractor.dart';
import 'zip_pdf_extractor_types.dart';

Future<ZipExtractResult> runZipExtraction({
  required ZipExtractParams params,
  required ZipPackageDownloader zipDownloader,
  void Function(int extracted, int total)? onExtractProgress,
}) async {
  final zipBytes = await zipDownloader.readZipBytes(params.zipPath);
  final paramsWithBytes = ZipExtractParams(
    zipPath: params.zipPath,
    rootPath: params.rootPath,
    expectedPdfIds: params.expectedPdfIds,
    skipPdfIds: params.skipPdfIds,
    zipBytes: zipBytes,
  );

  final result = await compute(extractZipPdfs, paramsWithBytes);

  if (onExtractProgress != null && result.items.isNotEmpty) {
    onExtractProgress(result.items.length, params.expectedPdfIds.length);
  }

  return result;
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
