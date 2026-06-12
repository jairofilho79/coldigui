import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../catalog/domain/entities/louvor.dart';

/// Converte [Louvor.pdfId] em path relativo para [PdfSourceResolver] (UC-04).
abstract final class LouvorPdfPath {
  /// Retorna `/assets/...` a partir do pdfId Base64 do manifest.
  ///
  /// O manifest em produção codifica `{classificacao}/{arquivo}.pdf` sem o
  /// prefixo `assets/`; fixtures de teste podem incluir `assets/` — ambos
  /// são normalizados para fetch remoto via [PdfSourceResolver].
  static String fromLouvor(Louvor louvor) {
    var relPath = PdfPathNormalizer.getPdfRelPath(louvor.pdfId);
    if (!relPath.startsWith('assets/')) {
      relPath = 'assets/$relPath';
    }
    return '/$relPath';
  }
}
