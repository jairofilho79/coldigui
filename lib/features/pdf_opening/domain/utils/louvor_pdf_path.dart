import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../catalog/domain/entities/louvor.dart';

/// Path remoto do PDF de um [Louvor] para [PdfSourceResolver] (UC-04).
abstract final class LouvorPdfPath {
  /// `/assets/praises/<praise>/<material>.pdf`, derivado do [Louvor.pdfId]
  /// (o adapter coldigom põe em `Louvor.pdf` só o nome do ficheiro). O
  /// `AssetBaseUrlResolver` escolhe a base coldigom pelo prefixo.
  static String fromLouvor(Louvor louvor) =>
      '/${PdfPathNormalizer.getPdfRelPath(louvor.pdfId)}';
}
