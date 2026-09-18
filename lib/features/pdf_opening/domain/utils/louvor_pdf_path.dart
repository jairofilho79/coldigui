import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../catalog/domain/entities/louvor.dart';

/// Path/URL remoto do PDF de um [Louvor] para [PdfSourceResolver] (UC-04).
abstract final class LouvorPdfPath {
  /// URL absoluta do manifest (`pdf` começa por `http(s)://`) ou, senão,
  /// `/assets/...` derivado do [Louvor.pdfId].
  static String fromLouvor(Louvor louvor) =>
      remotePath(pdf: louvor.pdf, pdfId: louvor.pdfId);

  /// [pdf] absoluto vence; caso contrário deriva de [pdfId].
  ///
  /// O manifest servido pelo coldigom traz `pdf` absoluto
  /// (`https://coldigom-api…/assets/praises/<praise>/<material>.pdf`). O
  /// fallback cobre o cache Isar anterior ao primeiro sync, fixtures e os
  /// materiais Coldigom nativos (`pdf` é só o nome do ficheiro): aí o path
  /// `/assets/...` passa por [AssetBaseUrlResolver], que escolhe a base pelo
  /// prefixo `assets/praises/`.
  static String remotePath({required String pdf, required String pdfId}) {
    final trimmed = pdf.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('https://') || lower.startsWith('http://')) {
      return trimmed;
    }
    var relPath = PdfPathNormalizer.getPdfRelPath(pdfId);
    if (!relPath.startsWith('assets/')) {
      relPath = 'assets/$relPath';
    }
    return '/$relPath';
  }
}
