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

  test('pdf absoluto (manifest coldigom) vence a derivação por pdfId', () {
    final louvor = Louvor.fromManifest(
      nome: 'Teste',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
      pdfId: _encodePdfId('ColAdultos/001.pdf'),
    );

    expect(
      LouvorPdfPath.fromLouvor(louvor),
      'https://coldigom.test/assets/praises/p1/m1.pdf',
    );
  });

  test('pdf só com nome de ficheiro continua na derivação legada', () {
    final louvor = _louvorWithPdfId('ColAdultos/001.pdf'); // pdf: '001.pdf'
    expect(LouvorPdfPath.fromLouvor(louvor), '/assets/ColAdultos/001.pdf');
  });

  test('remotePath aceita http e ignora espaços à volta', () {
    expect(
      LouvorPdfPath.remotePath(pdf: ' http://x/a.pdf ', pdfId: 'ignored'),
      'http://x/a.pdf',
    );
  });
}
