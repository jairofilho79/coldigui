import 'dart:io';

import 'package:archive/archive.dart';

import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../domain/entities/offline_pdf_batch_item.dart';
import 'pdf_integrity_validator.dart';

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

  /// Nomes relativos de entradas PDF no ZIP sem pdfId no manifest.
  final List<String> unmatchedEntries;
}

/// Extrai PDFs de [params.zipPath] e grava em [params.rootPath] (isolate-safe).
ZipExtractResult extractZipPdfs(ZipExtractParams params) {
  if (!_hasZipMagicBytesSync(params.zipPath)) {
    throw FormatException('ZIP corrompido ou inválido: ${params.zipPath}');
  }

  final inputStream = InputFileStream(params.zipPath);
  Archive archive;
  try {
    try {
      archive = ZipDecoder().decodeStream(inputStream);
    } on Object {
      throw FormatException('ZIP corrompido ou inválido: ${params.zipPath}');
    }
  } finally {
    inputStream.closeSync();
  }

  final skipSet = params.skipPdfIds.toSet();
  final relPathToPdfId = <String, String>{};
  for (final pdfId in params.expectedPdfIds) {
    relPathToPdfId[_normalizeRelPath(PdfPathNormalizer.getPdfRelPath(pdfId))] =
        pdfId;
  }

  final items = <ExtractedPdfItem>[];
  final unmatched = <String>[];

  for (final entry in archive) {
    if (!entry.isFile) continue;

    final entryName = entry.name.replaceAll(r'\', '/');
    if (!entryName.toLowerCase().endsWith('.pdf')) continue;

    final normalizedEntry = _normalizeRelPath(entryName);
    final pdfId = relPathToPdfId[normalizedEntry];
    if (pdfId == null) {
      unmatched.add(normalizedEntry);
      continue;
    }
    if (skipSet.contains(pdfId)) continue;

    final relPath = _storageRelPath(pdfId);
    final absolutePath = _writeEntryAtomic(entry, params.rootPath, relPath);
    if (absolutePath == null) continue;

    final fileSize = File(absolutePath).lengthSync();
    if (fileSize == 0) continue;

    items.add(
      ExtractedPdfItem(
        pdfId: pdfId,
        absolutePath: absolutePath,
        fileSize: fileSize,
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

bool _hasZipMagicBytesSync(String path) {
  try {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 2) return false;
    final handle = file.openSync();
    try {
      final header = handle.readSync(2);
      return header.length == 2 && header[0] == 0x50 && header[1] == 0x4B; // PK
    } finally {
      handle.closeSync();
    }
  } on Object {
    return false;
  }
}

String? _writeEntryAtomic(ArchiveFile entry, String rootPath, String relPath) {
  final targetFile = File('$rootPath/$relPath');
  final tmpFile = File('${targetFile.path}.tmp');

  targetFile.parent.createSync(recursive: true);

  final outStream = OutputFileStream(tmpFile.path);
  try {
    entry.writeContent(outStream);
  } on Object {
    outStream.closeSync();
    if (tmpFile.existsSync()) {
      tmpFile.deleteSync();
    }
    return null;
  }
  outStream.closeSync();

  if (!PdfIntegrityValidator.isValidPdfFileSync(tmpFile.path)) {
    tmpFile.deleteSync();
    return null;
  }

  try {
    tmpFile.renameSync(targetFile.path);
    return targetFile.path;
  } on Object {
    if (tmpFile.existsSync()) {
      tmpFile.deleteSync();
    }
    return null;
  }
}
