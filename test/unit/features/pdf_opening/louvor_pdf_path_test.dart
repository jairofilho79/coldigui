import 'dart:convert';

import 'package:coldigui/core/utils/pdf_path_normalizer.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/pdf_opening/domain/utils/louvor_pdf_path.dart';
import 'package:flutter_test/flutter_test.dart';

String _encodePdfId(String path) {
  return base64Url
      .encode(utf8.encode(path))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

Louvor _louvorWithPdfId(String relPath) {
  return Louvor.fromManifest(
    nome: 'Teste',
    numero: '001',
    categoria: 'Partitura',
    classificacao: 'ColAdultos',
    pdf: '001.pdf',
    pdfId: _encodePdfId(relPath),
  );
}

void main() {
  test('LouvorPdfPath.fromLouvor retorna path com prefixo /assets/', () {
    const relPath = 'assets/ColAdultos/001.pdf';
    final louvor = _louvorWithPdfId(relPath);

    expect(LouvorPdfPath.fromLouvor(louvor), '/$relPath');
    expect(
      PdfPathNormalizer.getPdfRelPath(louvor.pdfId),
      relPath,
    );
  });

  test('LouvorPdfPath preserva acentos do pdfId', () {
    const relPath = 'assets/ColAdultos/Cifra nível I/001.pdf';
    final louvor = _louvorWithPdfId(relPath);

    expect(LouvorPdfPath.fromLouvor(louvor), '/$relPath');
  });

  test(
      'LouvorPdfPath adiciona assets/ quando pdfId omite prefixo (manifest produção)',
      () {
    const relPath = 'ColAdultos/001.pdf';
    final louvor = _louvorWithPdfId(relPath);

    expect(LouvorPdfPath.fromLouvor(louvor), '/assets/ColAdultos/001.pdf');
  });
}
