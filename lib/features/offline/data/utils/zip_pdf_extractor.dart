import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../domain/entities/offline_pdf_batch_item.dart';

/// Parâmetros serializáveis para extração em isolate (`compute`).
class ZipExtractParams {
  const ZipExtractParams({
    required this.zipPath,
    required this.rootPath,
    required this.expectedPdfIds,
    required this.skipPdfIds,
  });

  final String zipPath;
  final String rootPath;
  final List<String> expectedPdfIds;
  final List<String> skipPdfIds;
}

/// Resultado serializável da extração em isolate.
class ZipExtractResult {
  const ZipExtractResult({
    required this.items,
    required this.unmatchedEntries,
  });

  final List<ExtractedPdfItem> items;
  final int unmatchedEntries;
}

/// Extrai PDFs de [params.zipPath] e grava em [params.rootPath] (isolate-safe).
ZipExtractResult extractZipPdfs(ZipExtractParams params) {
  final zipBytes = File(params.zipPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(zipBytes);

  final skipSet = params.skipPdfIds.toSet();
  final relPathToPdfId = <String, String>{};
  for (final pdfId in params.expectedPdfIds) {
    relPathToPdfId[_normalizeRelPath(PdfPathNormalizer.getPdfRelPath(pdfId))] =
        pdfId;
  }

  final items = <ExtractedPdfItem>[];
  var unmatched = 0;

  for (final file in archive) {
    if (!file.isFile) continue;

    final entryName = file.name.replaceAll(r'\', '/');
    if (!entryName.toLowerCase().endsWith('.pdf')) continue;

    final pdfId = relPathToPdfId[_normalizeRelPath(entryName)];
    if (pdfId == null) {
      unmatched++;
      continue;
    }
    if (skipSet.contains(pdfId)) continue;

    final bytes = file.content;
    if (bytes.isEmpty) continue;

    final relPath = _storageRelPath(pdfId);
    final absolutePath = _writeAtomic(
      bytes,
      params.rootPath,
      relPath,
    );

    items.add(
      ExtractedPdfItem(
        pdfId: pdfId,
        absolutePath: absolutePath,
        fileSize: bytes.length,
      ),
    );
  }

  return ZipExtractResult(items: items, unmatchedEntries: unmatched);
}

String _normalizeRelPath(String path) {
  var normalized = path.replaceAll(r'\', '/');
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.startsWith('assets/')) {
    normalized = normalized.substring('assets/'.length);
  }
  return normalized;
}

String _storageRelPath(String pdfId) {
  var rel = PdfPathNormalizer.getPdfRelPath(pdfId);
  if (rel.startsWith('assets/')) {
    rel = rel.substring('assets/'.length);
  }
  return rel;
}

String _writeAtomic(Uint8List bytes, String rootPath, String relPath) {
  final targetFile = File('$rootPath/$relPath');
  final tmpFile = File('${targetFile.path}.tmp');

  targetFile.parent.createSync(recursive: true);

  try {
    tmpFile.writeAsBytesSync(bytes, flush: true);
    tmpFile.renameSync(targetFile.path);
    return targetFile.path;
  } on Object {
    if (tmpFile.existsSync()) {
      tmpFile.deleteSync();
    }
    rethrow;
  }
}
