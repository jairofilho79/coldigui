import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart' as path_provider;

import 'save_pdf_platform.dart';

/// Subdiretório em documents — espelha [SavePdf.savedPdfsSubdir].
const kSavedPdfsSubdir = 'saved_pdfs';

typedef GetApplicationDocumentsDirectoryFn = Future<Directory> Function();

SavePdfPlatform createSavePdfPlatformImpl({
  GetApplicationDocumentsDirectoryFn? getApplicationDocumentsDirectory,
}) {
  return _NativeSavePdfPlatform(
    getApplicationDocumentsDirectory: getApplicationDocumentsDirectory,
  );
}

class _NativeSavePdfPlatform implements SavePdfPlatform {
  _NativeSavePdfPlatform({
    GetApplicationDocumentsDirectoryFn? getApplicationDocumentsDirectory,
  }) : _getApplicationDocumentsDirectory =
           getApplicationDocumentsDirectory ??
           path_provider.getApplicationDocumentsDirectory;

  final GetApplicationDocumentsDirectoryFn _getApplicationDocumentsDirectory;

  @override
  Future<String> savePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final docsDir = await _getApplicationDocumentsDirectory();
    final targetDir = Directory('${docsDir.path}/$kSavedPdfsSubdir');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetFile = File('${targetDir.path}/$fileName');
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.path;
  }
}
