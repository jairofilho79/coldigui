import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';

import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../domain/entities/offline_pdf_batch_item.dart';
import 'pdf_integrity_validator.dart';

/// Intervalo de reporte de progresso durante extração em isolate (backlog #5).
const zipExtractProgressInterval = 25;

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

/// Progresso emitido pelo isolate a cada [zipExtractProgressInterval] PDFs.
class ZipExtractProgressReport {
  const ZipExtractProgressReport({
    required this.extracted,
    required this.total,
  });

  final int extracted;
  final int total;
}

/// Resultado serializável da extração em isolate.
class ZipExtractResult {
  const ZipExtractResult({
    required this.items,
    required this.unmatchedEntries,
    this.failedPdfIds = const [],
  });

  final List<ExtractedPdfItem> items;

  /// Nomes relativos de entradas PDF no ZIP sem pdfId no manifest.
  final List<String> unmatchedEntries;

  /// pdfIds esperados cujo conteúdo não pôde ser gravado ou validado.
  final List<String> failedPdfIds;
}

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

  final skipSet = params.skipPdfIds.toSet();
  final relPathToPdfId = <String, String>{};
  for (final pdfId in params.expectedPdfIds) {
    relPathToPdfId[_normalizeRelPath(PdfPathNormalizer.getPdfRelPath(pdfId))] =
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

    final normalizedEntry = _normalizeRelPath(entryName);
    final pdfId = relPathToPdfId[normalizedEntry];
    if (pdfId == null) {
      unmatched.add(normalizedEntry);
      continue;
    }
    if (skipSet.contains(pdfId)) continue;

    final relPath = _storageRelPath(pdfId);
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
