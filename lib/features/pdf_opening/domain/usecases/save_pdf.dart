import 'dart:io';

import 'package:path_provider/path_provider.dart' as path_provider;

import '../../../pdf_reader/domain/usecases/open_pdf_document.dart';
import '../../data/datasources/pdf_bytes_datasource.dart';
import '../utils/is_local_pdf_path.dart';
import '../utils/pdf_file_name_sanitizer.dart';

typedef GetApplicationDocumentsDirectoryFn = Future<Directory> Function();

/// UC-04 — Salvar PDF em `documents/saved_pdfs/` (Fase 2.5).
///
/// Fase 3.4: path em cache offline → `File.copy` do cache — sem re-download HTTP.
class SavePdf {
  SavePdf(
    this._bytesDatasource,
    this._openPdf, {
    GetApplicationDocumentsDirectoryFn? getApplicationDocumentsDirectory,
  }) : _getApplicationDocumentsDirectory = getApplicationDocumentsDirectory ??
            path_provider.getApplicationDocumentsDirectory;

  static const String savedPdfsSubdir = 'saved_pdfs';

  final PdfBytesDatasource _bytesDatasource;
  final OpenPdfDocument _openPdf;
  final GetApplicationDocumentsDirectoryFn _getApplicationDocumentsDirectory;

  /// Salva PDF em `documents/saved_pdfs/`; retorna path absoluto do destino.
  ///
  /// Path local ([isLocalPdfPath]): `File.copy` do cache — sem HTTP.
  /// Remoto/asset: valida → fetch bytes → `writeAsBytes`.
  Future<String> call({
    required String filePath,
    String? fileName,
  }) async {
    _openPdf.validateFilePath(filePath);

    final safeName = PdfFileNameSanitizer.sanitize(
      fileName ?? _basename(filePath),
    );

    final docsDir = await _getApplicationDocumentsDirectory();
    final targetDir = Directory('${docsDir.path}/$savedPdfsSubdir');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetFile = File('${targetDir.path}/$safeName');

    if (isLocalPdfPath(filePath)) {
      await File(filePath).copy(targetFile.path);
      return targetFile.path;
    }

    final bytes = await _bytesDatasource.fetchBytes(filePath);
    await targetFile.writeAsBytes(bytes, flush: true);

    return targetFile.path;
  }

  static String _basename(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final index = normalized.lastIndexOf('/');
    return index == -1 ? normalized : normalized.substring(index + 1);
  }
}
