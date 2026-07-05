import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../domain/entities/offline_pdf_batch_item.dart';
import 'pdf_integrity_validator.dart';
import 'zip_pdf_extractor_shared.dart';
import 'zip_pdf_extractor_types.dart';

/// Extrai PDFs de [params.zipBytes] (web-safe — sem `dart:io`).
ZipExtractResult extractZipPdfs(ZipExtractParams params) {
  final zipBytes = params.zipBytes;
  if (zipBytes == null) {
    throw FormatException('ZIP corrompido ou inválido: ${params.zipPath}');
  }
  if (!hasZipMagicBytes(zipBytes)) {
    throw FormatException('ZIP corrompido ou inválido: ${params.zipPath}');
  }

  Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zipBytes);
  } on Object {
    throw FormatException('ZIP corrompido ou inválido: ${params.zipPath}');
  }

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

    final content = Uint8List.fromList(entry.content);
    if (content.isEmpty) {
      failedPdfIds.add(pdfId);
      continue;
    }
    if (!PdfIntegrityValidator.hasValidPdfMagicBytes(
      content.length >= 4 ? content.sublist(0, 4) : content,
    )) {
      failedPdfIds.add(pdfId);
      continue;
    }

    items.add(
      ExtractedPdfItem(
        pdfId: pdfId,
        absolutePath: '',
        fileSize: content.length,
        contentBytes: content,
      ),
    );
  }

  return ZipExtractResult(
    items: items,
    unmatchedEntries: unmatched,
    failedPdfIds: failedPdfIds,
  );
}
