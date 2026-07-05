import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';

import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../domain/entities/offline_pdf_batch_item.dart';
import 'pdf_integrity_validator.dart';
import 'zip_pdf_extractor_shared.dart';
import 'zip_pdf_extractor_types.dart';

/// Entry point para [Isolate.spawn] com reporte de progresso.
void extractZipPdfsIsolateEntry(List<Object?> args) {
  final params = args[0] as ZipExtractParams;
  final sendPort = args[1] as SendPort;
  try {
    final result = _extractZipPdfsImpl(params, progressPort: sendPort);
    sendPort.send(result);
  } on Object catch (e, st) {
    sendPort.send(<Object?>[e, st]);
  }
}

/// Extrai PDFs de [params.zipPath] e grava em [params.rootPath] (isolate-safe).
ZipExtractResult extractZipPdfs(ZipExtractParams params) =>
    _extractZipPdfsImpl(params);

ZipExtractResult _extractZipPdfsImpl(
  ZipExtractParams params, {
  SendPort? progressPort,
}) {
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

  return _extractArchive(archive, params: params, progressPort: progressPort);
}

ZipExtractResult _extractArchive(
  Archive archive, {
  required ZipExtractParams params,
  SendPort? progressPort,
}) {
  final skipSet = params.skipPdfIds.toSet();
  final relPathToPdfId = <String, String>{};
  for (final pdfId in params.expectedPdfIds) {
    relPathToPdfId[normalizeZipEntryRelPath(
          PdfPathNormalizer.getPdfRelPath(pdfId),
        )] =
        pdfId;
  }

  final items = <ExtractedPdfItem>[];
  final unmatched = <String>[];
  final failedPdfIds = <String>[];
  final totalExpected = params.expectedPdfIds.length;
  var extractedCount = 0;

  for (final entry in archive) {
    if (!entry.isFile) continue;

    final entryName = entry.name.replaceAll(r'\', '/');
    if (!entryName.toLowerCase().endsWith('.pdf')) continue;

    final normalizedEntry = normalizeZipEntryRelPath(entryName);
    final pdfId = relPathToPdfId[normalizedEntry];
    if (pdfId == null) {
      unmatched.add(normalizedEntry);
      continue;
    }
    if (skipSet.contains(pdfId)) continue;

    final relPath = storageRelPathForPdfId(pdfId);
    final absolutePath = _writeEntryAtomic(entry, params.rootPath, relPath);
    if (absolutePath == null) {
      failedPdfIds.add(pdfId);
      continue;
    }

    final fileSize = File(absolutePath).lengthSync();
    if (fileSize == 0) {
      failedPdfIds.add(pdfId);
      continue;
    }

    items.add(
      ExtractedPdfItem(
        pdfId: pdfId,
        absolutePath: absolutePath,
        fileSize: fileSize,
      ),
    );

    extractedCount++;
    if (progressPort != null &&
        extractedCount % zipExtractProgressInterval == 0) {
      progressPort.send(
        ZipExtractProgressReport(
          extracted: extractedCount,
          total: totalExpected,
        ),
      );
    }
  }

  return ZipExtractResult(
    items: items,
    unmatchedEntries: unmatched,
    failedPdfIds: failedPdfIds,
  );
}

bool _hasZipMagicBytesSync(String path) {
  try {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 2) return false;
    final handle = file.openSync();
    try {
      final header = handle.readSync(2);
      return hasZipMagicBytes(header);
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
