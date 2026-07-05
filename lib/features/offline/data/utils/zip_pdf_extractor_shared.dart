import '../../../../core/utils/pdf_path_normalizer.dart';

String normalizeZipEntryRelPath(String path) {
  var normalized = path.replaceAll(r'\', '/');
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.startsWith('assets/')) {
    normalized = normalized.substring('assets/'.length);
  }
  return normalized;
}

String storageRelPathForPdfId(String pdfId) {
  var rel = PdfPathNormalizer.getPdfRelPath(pdfId);
  if (rel.startsWith('assets/')) {
    rel = rel.substring('assets/'.length);
  }
  return rel;
}

bool hasZipMagicBytes(List<int> bytes) =>
    bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
