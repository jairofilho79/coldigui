import 'dart:convert';

import 'package:coldigui/core/utils/pdf_path_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

String _encodePdfId(String path) {
  return base64Url
      .encode(utf8.encode(path))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

void main() {
  group('PdfPathNormalizer.getPdfRelPath', () {
    test('preserva acentos (Cifra nível I/II)', () {
      const path = 'assets/ColAdultos/Cifra nível I/001.pdf';
      expect(PdfPathNormalizer.getPdfRelPath(_encodePdfId(path)), path);
    });

    test('preserva case', () {
      const path = 'assets/ColAdultos/Cifra/ABC.pdf';
      expect(PdfPathNormalizer.getPdfRelPath(_encodePdfId(path)), path);
    });

    test('decodifica pdfId URL-safe com padding implícito', () {
      const path = 'assets/ColAdultos/Cifra nível II/002.pdf';
      final pdfId = _encodePdfId(path);
      expect(PdfPathNormalizer.getPdfRelPath(pdfId), path);
    });

    test('paths com espaços e caracteres especiais', () {
      const path = 'assets/ColAdultos/Partitura & Cifra/001 - Aleluia.pdf';
      expect(PdfPathNormalizer.getPdfRelPath(_encodePdfId(path)), path);
    });

    test('aceita Base64 padrão com + e /', () {
      const path = 'assets/ColJovens/001.pdf';
      final pdfId = base64.encode(utf8.encode(path));
      expect(PdfPathNormalizer.getPdfRelPath(pdfId), path);
    });
  });

  group('PdfPathNormalizer.normalizePdfUrl', () {
    test('adiciona prefixo assets/', () {
      expect(
        PdfPathNormalizer.normalizePdfUrl('ColAdultos/001.pdf'),
        'assets/coladultos/001.pdf',
      );
    });

    test('remove acentos e converte para lowercase', () {
      expect(
        PdfPathNormalizer.normalizePdfUrl(
          'assets/ColAdultos/Cifra nível I/001.pdf',
        ),
        'assets/coladultos/cifra nivel i/001.pdf',
      );
    });

    test('remove protocolo e domínio', () {
      expect(
        PdfPathNormalizer.normalizePdfUrl(
          'https://example.com/assets/ColAdultos/001.pdf',
        ),
        'assets/coladultos/001.pdf',
      );
    });

    test('decodifica URI encoding', () {
      expect(
        PdfPathNormalizer.normalizePdfUrl('assets/ColAdultos%2F001.pdf'),
        'assets/coladultos/001.pdf',
      );
    });

    test('normaliza barras invertidas', () {
      expect(
        PdfPathNormalizer.normalizePdfUrl(r'assets\ColAdultos\001.pdf'),
        'assets/coladultos/001.pdf',
      );
    });
  });
}
