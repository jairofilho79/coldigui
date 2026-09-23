import 'dart:convert';

import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';

import 'material_id_kind.dart';
import 'pdf_path_normalizer.dart';

/// Codifica path relativo do asset em `pdfId` Base64 URL-safe UTF-8.
String encodePdfId(String relPath) {
  return base64Url
      .encode(utf8.encode(relPath))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

/// `true` quando [pdfId] aponta para material coldigom (`assets/praises/...`).
///
/// Depois do fim da fonte PLPCG é também o detetor de id legado da
/// normalização (spec 2026-09-23 §6.1) — ver [isLegacyPdfId].
bool isColdigomPdfId(String pdfId) {
  try {
    return PdfPathNormalizer.getPdfRelPath(pdfId).startsWith('assets/praises/');
  } on Object {
    return false;
  }
}

/// Infere [LouvorDataSource] a partir de [pdfId] quando não há entidade.
LouvorDataSource louvorDataSourceFromPdfId(String pdfId) {
  return isColdigomPdfId(pdfId)
      ? LouvorDataSource.coldigom
      : LouvorDataSource.plpcg;
}

/// Id legado do manifest PLPCG (spec 2026-09-23 §6.1): entrada **PDF** cujo
/// path não está em `assets/praises/` — inclui os 36 `assets/PES/…`.
///
/// É o que `NormalizeLegacyMaterialIds` troca pelo id coldigom via crosswalk.
/// Cifra, áudio, gesto, letra e YouTube nunca são legados.
bool isLegacyPdfId(String id) =>
    materialIdKindOf(id) == MaterialKind.pdf && !isColdigomPdfId(id);

const _praisesPathMarker = '/assets/praises/';
const _praisesR2Prefix = 'assets/praises/';

/// Id coldigom do material cuja URL é [url]
/// (`https://…/assets/praises/<praise>/<material>.<ext>`).
///
/// É `encodePdfId(r2Key)` — o mesmo id que `ColdigomLouvorAdapter` cunha —,
/// com o `r2Key` lido da URL e **não** montado a partir de
/// `praiseId`/`materialId`: materiais movidos vivem na pasta de outro praise
/// e só a URL diz o path real (desvio 2 do spec de 18/09). Serve o crosswalk
/// (`ColdigomRemoteDatasource.resolveLegacyPdfIds`).
///
/// Query string (`?…`) e fragment (`#…`) são descartados antes de procurar o
/// path — não fazem parte do `r2Key` (ruling do pre-flight 6.7).
///
/// `null` quando [url] não tem `/assets/praises/<praise>/<ficheiro>` ou o
/// percent-encoding é inválido.
String? coldigomPdfIdFromAssetUrl(String url) {
  final withoutQueryAndFragment = _stripQueryAndFragment(url);
  final index = withoutQueryAndFragment.indexOf(_praisesPathMarker);
  if (index < 0) return null;
  final r2Key = withoutQueryAndFragment.substring(
    index + 1,
  ); // sem a barra inicial
  final rest = r2Key.substring(_praisesR2Prefix.length);
  if (rest.isEmpty || !rest.contains('/')) return null;
  try {
    return encodePdfId(Uri.decodeComponent(r2Key));
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
}

/// Corta [url] no primeiro `?` ou `#`, o que vier primeiro.
String _stripQueryAndFragment(String url) {
  var end = url.length;
  final queryIndex = url.indexOf('?');
  if (queryIndex != -1 && queryIndex < end) end = queryIndex;
  final fragmentIndex = url.indexOf('#');
  if (fragmentIndex != -1 && fragmentIndex < end) end = fragmentIndex;
  return url.substring(0, end);
}
