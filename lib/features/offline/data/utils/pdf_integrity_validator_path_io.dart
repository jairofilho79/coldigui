import 'dart:io';

import 'pdf_integrity_validator.dart';

Future<bool> validatePdfStoragePath(String path) async {
  try {
    final stat = await FileStat.stat(path);
    if (stat.type != FileSystemEntityType.file || stat.size < 4) {
      return false;
    }
    final bytes = await File(path).openRead(0, 4).first;
    return PdfIntegrityValidator.hasValidPdfMagicBytes(bytes);
  } on FileSystemException {
    return false;
  }
}

bool validatePdfStoragePathSync(String path) {
  try {
    final stat = FileStat.statSync(path);
    if (stat.type != FileSystemEntityType.file || stat.size < 4) {
      return false;
    }
    final raf = File(path).openSync();
    try {
      final bytes = raf.readSync(4);
      return PdfIntegrityValidator.hasValidPdfMagicBytes(bytes);
    } finally {
      raf.closeSync();
    }
  } on FileSystemException {
    return false;
  }
}
