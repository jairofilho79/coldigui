import '../../../../core/utils/pdf_id_codec.dart';

const _praisesPrefix = '/assets/praises/';

/// [_praisesPrefix] sem a barra inicial — o começo do `r2Key`.
const _praisesR2Prefix = 'assets/praises/';

/// Id Coldigom nativo do PDF que o manifest aponta em [pdf] (URL absoluta
/// `https://…/assets/praises/<praise>/<material>.pdf`).
///
/// É `encodePdfId(r2Key)` — o mesmo id que `ColdigomLouvorAdapter` cunha para
/// o material —, com o `r2Key` lido da URL e **não** montado a partir de
/// `praiseId`/`materialId`: 64 entradas do manifest (e 1473 PDFs do coldigom)
/// vivem na pasta de outro praise (material movido) e só a URL diz o path real.
///
/// `null` quando [pdf] não contém `/assets/praises/` (nome de ficheiro, cache
/// antigo, fixtures).
String? coldigomPdfIdFromManifestPdf(String pdf) {
  final index = pdf.indexOf(_praisesPrefix);
  if (index < 0) return null;
  final r2Key = pdf.substring(index + 1); // sem a barra inicial
  final rest = r2Key.substring(_praisesR2Prefix.length);
  if (rest.isEmpty || !rest.contains('/')) return null;
  try {
    return encodePdfId(Uri.decodeComponent(r2Key));
  } on ArgumentError {
    return null;
  }
}
