import 'dart:io';

/// Validação compartilhada de integridade de arquivos PDF locais (magic bytes `%PDF`).
abstract final class PdfIntegrityValidator {
  static const _pdfMagic = [0x25, 0x50, 0x44, 0x46]; // %PDF

  static bool hasValidPdfMagicBytes(List<int> bytes) =>
      bytes.length == 4 &&
      bytes[0] == _pdfMagic[0] &&
      bytes[1] == _pdfMagic[1] &&
      bytes[2] == _pdfMagic[2] &&
      bytes[3] == _pdfMagic[3];

  static Future<bool> isValidPdfFile(String path) async {
    try {
      final stat = await FileStat.stat(path);
      if (stat.type != FileSystemEntityType.file || stat.size < 4) {
        return false;
      }
      final bytes = await File(path).openRead(0, 4).first;
      return hasValidPdfMagicBytes(bytes);
    } on FileSystemException {
      return false;
    }
  }

  /// Variante síncrona para isolates (`compute`) e extração ZIP.
  static bool isValidPdfFileSync(String path) {
    try {
      final stat = FileStat.statSync(path);
      if (stat.type != FileSystemEntityType.file || stat.size < 4) {
        return false;
      }
      final raf = File(path).openSync();
      try {
        final bytes = raf.readSync(4);
        return hasValidPdfMagicBytes(bytes);
      } finally {
        raf.closeSync();
      }
    } on FileSystemException {
      return false;
    }
  }
}
