import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/core/utils/pdf_path_normalizer.dart';

/// Extrai o `praise.id` do path coldigom embutido em [pdfId].
///
/// Formato: `assets/praises/{praiseId}/{materialId}.pdf`
String? coldigomPraiseIdFromPdfId(String pdfId) {
  if (!isColdigomPdfId(pdfId)) return null;
  try {
    final path = PdfPathNormalizer.getPdfRelPath(pdfId);
    const prefix = 'assets/praises/';
    if (!path.startsWith(prefix)) return null;
    final rest = path.substring(prefix.length);
    final slash = rest.indexOf('/');
    if (slash <= 0) return null;
    return rest.substring(0, slash);
  } on Object {
    return null;
  }
}
