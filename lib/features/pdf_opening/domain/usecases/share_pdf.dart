import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import '../../../pdf_reader/domain/usecases/open_pdf_document.dart';
import '../../data/datasources/pdf_bytes_datasource.dart';
import '../utils/pdf_file_name_sanitizer.dart';

typedef ShareXFilesFn =
    Future<void> Function(
      List<XFile> files, {
      String? subject,
      Rect? sharePositionOrigin,
    });

/// UC-04 — Compartilhar PDF via [share_plus] (Fase 2.5 / D4 OA).
///
/// Usa [XFile.fromData] em todas as plataformas — sem arquivos temporários.
class SharePdf {
  SharePdf(this._bytesDatasource, this._openPdf, {ShareXFilesFn? shareXFiles})
    : _shareXFiles = shareXFiles ?? _defaultShareXFiles;

  final PdfBytesDatasource _bytesDatasource;
  final OpenPdfDocument _openPdf;
  final ShareXFilesFn _shareXFiles;

  /// Compartilha PDF via sheet nativo / Web Share API.
  Future<void> call({
    required String filePath,
    String? displayName,
    Rect? sharePositionOrigin,
  }) async {
    _openPdf.validateFilePath(filePath);

    final bytes = await _bytesDatasource.fetchBytes(filePath);
    final fileName = PdfFileNameSanitizer.sanitize(
      displayName ?? _basename(filePath),
    );

    await _shareXFiles(
      [XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName)],
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
