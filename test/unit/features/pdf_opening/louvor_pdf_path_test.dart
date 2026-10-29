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
  test('deriva /assets/praises/… do pdfId coldigom', () {
    const relPath = 'assets/praises/p1/m1.pdf';
    final louvor = _louvorWithPdfId(relPath);

    expect(LouvorPdfPath.fromLouvor(louvor), '/$relPath');
    expect(PdfPathNormalizer.getPdfRelPath(louvor.pdfId), relPath);
  });

  test('preserva acentos e espaços do path', () {
    const relPath = 'assets/praises/p1/Cifra nível I.pdf';

    expect(LouvorPdfPath.fromLouvor(_louvorWithPdfId(relPath)), '/$relPath');
  });

  test('ignora o campo pdf (só nome do ficheiro no adapter)', () {
    final louvor = Louvor.fromManifest(
      nome: 'Teste',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'Coro',
      pdf: 'https://outro.test/qualquer.pdf',
      pdfId: _encodePdfId('assets/praises/p1/m1.pdf'),
    );

    expect(LouvorPdfPath.fromLouvor(louvor), '/assets/praises/p1/m1.pdf');
  });
}
