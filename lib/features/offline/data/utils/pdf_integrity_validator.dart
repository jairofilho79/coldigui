import 'pdf_integrity_validator_path_io.dart'
    if (dart.library.js_interop) 'pdf_integrity_validator_path_web.dart';

/// Validação compartilhada de integridade de PDFs locais (magic bytes `%PDF`).
abstract final class PdfIntegrityValidator {
  static const _pdfMagic = [0x25, 0x50, 0x44, 0x46]; // %PDF

  static bool hasValidPdfMagicBytes(List<int> bytes) =>
      bytes.length == 4 &&
      bytes[0] == _pdfMagic[0] &&
      bytes[1] == _pdfMagic[1] &&
      bytes[2] == _pdfMagic[2] &&
      bytes[3] == _pdfMagic[3];

  static Future<bool> isValidPdfFile(String path) =>
      validatePdfStoragePath(path);

  /// Variante síncrona para isolates (`compute`) e extração ZIP.
  static bool isValidPdfFileSync(String path) =>
      validatePdfStoragePathSync(path);
}
