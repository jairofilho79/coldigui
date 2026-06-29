import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:share_plus/share_plus.dart';

import '../../../pdf_reader/domain/usecases/open_pdf_document.dart';
import '../../data/datasources/pdf_bytes_datasource.dart';
import '../utils/is_local_pdf_path.dart';
import '../utils/pdf_file_name_sanitizer.dart';

typedef ShareXFilesFn =
    Future<void> Function(
      List<XFile> files, {
      String? subject,
      Rect? sharePositionOrigin,
    });

typedef GetTemporaryDirectoryFn = Future<Directory> Function();

/// UC-04 — Compartilhar PDF via [share_plus] (Fase 2.5).
///
/// Fase 3.4: path em cache offline → `Share.shareXFiles([XFile(localPath)])`
/// sem reler bytes; remoto/asset mantém fluxo atual via [PdfBytesDatasource].
class SharePdf {
  SharePdf(
    this._bytesDatasource,
    this._openPdf, {
    GetTemporaryDirectoryFn? getTemporaryDirectory,
    ShareXFilesFn? shareXFiles,
  }) : _getTemporaryDirectory =
           getTemporaryDirectory ?? path_provider.getTemporaryDirectory,
       _shareXFiles = shareXFiles ?? _defaultShareXFiles;

  final PdfBytesDatasource _bytesDatasource;
  final OpenPdfDocument _openPdf;
  final GetTemporaryDirectoryFn _getTemporaryDirectory;
  final ShareXFilesFn _shareXFiles;

  /// Compartilha PDF via sheet nativo ([share_plus]).
  ///
  /// Path local ([isLocalPdfPath]): `Share.shareXFiles([XFile(localPath)])` direto.
  /// Remoto/asset: valida → [PdfBytesDatasource.fetchBytes] → temp → share.
  Future<void> call({
    required String filePath,
    String? displayName,
    Rect? sharePositionOrigin,
  }) async {
    _openPdf.validateFilePath(filePath);

    if (isLocalPdfPath(filePath)) {
      final fileName = PdfFileNameSanitizer.sanitize(
        displayName ?? _basename(filePath),
      );
      await _shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf', name: fileName)],
        subject: displayName ?? fileName,
        sharePositionOrigin: sharePositionOrigin,
      );
      return;
    }

    final bytes = await _bytesDatasource.fetchBytes(filePath);
    final fileName = PdfFileNameSanitizer.sanitize(
      displayName ?? _basename(filePath),
    );

    final tempDir = await _getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes, flush: true);

    await _shareXFiles(
      [XFile(tempFile.path, mimeType: 'application/pdf', name: fileName)],
      subject: displayName ?? fileName,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static String _basename(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final index = normalized.lastIndexOf('/');
    return index == -1 ? normalized : normalized.substring(index + 1);
  }
}

Future<void> _defaultShareXFiles(
  List<XFile> files, {
  String? subject,
  Rect? sharePositionOrigin,
}) {
  return SharePlus.instance.share(
    ShareParams(
      files: files,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}
