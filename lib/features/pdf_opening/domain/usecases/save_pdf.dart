import '../../../pdf_reader/domain/usecases/open_pdf_document.dart';
import '../../data/datasources/pdf_bytes_datasource.dart';
import '../../data/datasources/save_pdf_platform.dart';
import '../utils/pdf_file_name_sanitizer.dart';

/// UC-04 — Salvar PDF (Fase 2.5 / web D3 OA).
///
/// Nativo: grava em `documents/saved_pdfs/` via [SavePdfPlatform].
/// Web: dispara download do browser via [SavePdfPlatform].
class SavePdf {
  SavePdf(this._bytesDatasource, this._openPdf, this._platform);

  static const String savedPdfsSubdir = 'saved_pdfs';

  final PdfBytesDatasource _bytesDatasource;
  final OpenPdfDocument _openPdf;
  final SavePdfPlatform _platform;

  /// Salva PDF; retorna path absoluto (nativo) ou nome do arquivo (web download).
  Future<String> call({required String filePath, String? fileName}) async {
    _openPdf.validateFilePath(filePath);

    final safeName = PdfFileNameSanitizer.sanitize(
      fileName ?? _basename(filePath),
    );

    final bytes = await _bytesDatasource.fetchBytes(filePath);
    return _platform.savePdf(bytes: bytes, fileName: safeName);
  }

  static String _basename(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final index = normalized.lastIndexOf('/');
    return index == -1 ? normalized : normalized.substring(index + 1);
  }
}
