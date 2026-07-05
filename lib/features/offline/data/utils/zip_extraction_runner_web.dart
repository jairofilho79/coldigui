import 'package:flutter/foundation.dart';

import '../../../../core/utils/pdf_path_normalizer.dart';
import '../datasources/zip_package_downloader.dart';
import '../../domain/entities/offline_pdf_batch_item.dart';
import '../../domain/ports/pdf_storage_port.dart';
import 'zip_pdf_extractor.dart';

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

Future<List<ExtractedPdfItem>> persistExtractedItems(
  List<ExtractedPdfItem> items,
  PdfStoragePort store,
) async {
  final persisted = <ExtractedPdfItem>[];

  for (final item in items) {
    final bytes = item.contentBytes;
    if (bytes == null) {
      persisted.add(item);
      continue;
    }

    var relPath = PdfPathNormalizer.getPdfRelPath(item.pdfId);
    if (relPath.startsWith('assets/')) {
      relPath = relPath.substring('assets/'.length);
    }

    final storageKey = await store.writeAtomic(bytes, relPath);
    persisted.add(
      ExtractedPdfItem(
        pdfId: item.pdfId,
        absolutePath: storageKey,
        fileSize: bytes.length,
      ),
    );
  }

  return persisted;
}
