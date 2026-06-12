import '../../../../core/utils/pdf_path_normalizer.dart';

/// Deriva a classificação Isar (`ColAdultos`, etc.) a partir de [pdfId].
abstract final class OfflineCategoryResolver {
  static String fromPdfId(String pdfId) {
    var relPath = PdfPathNormalizer.getPdfRelPath(pdfId);
    if (relPath.startsWith('assets/')) {
      relPath = relPath.substring('assets/'.length);
    }

    final slashIndex = relPath.indexOf('/');
    if (slashIndex == -1) {
      return relPath;
    }
    return relPath.substring(0, slashIndex);
  }
}
