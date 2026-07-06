import 'dart:convert';

import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';

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
