import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encodePdfId', () {
    test('mesma saída do script do D1 (base64url sem padding)', () {
      // Os mesmos literais estão em workers/plpcg-catalog/scripts/
      // legacy_playlist_ids.test.ts — os dois lados cunham o mesmo id.
      expect(
        encodePdfId('assets/praises/p1/m1.pdf'),
        'YXNzZXRzL3ByYWlzZXMvcDEvbTEucGRm',
      );
      expect(
        encodePdfId('ColAdultos/Cifra nível I/001.pdf'),
        'Q29sQWR1bHRvcy9DaWZyYSBuw612ZWwgSS8wMDEucGRm',
      );
    });
  });

  group('isLegacyPdfId', () {
    test('PDF fora de assets/praises é legado (inclui assets/PES)', () {
      expect(isLegacyPdfId(encodePdfId('ColAdultos/001.pdf')), isTrue);
      expect(isLegacyPdfId(encodePdfId('assets/PES/Hino 1.pdf')), isTrue);
      expect(
        isLegacyPdfId(encodePdfId('ColAdultos/Cifra nível I/001.pdf')),
        isTrue,
      );
    });

    test('id coldigom de qualquer tipo não é legado', () {
      for (final path in [
        'assets/praises/p1/m1.pdf',
        'assets/praises/p1/m1.chord',
        'assets/praises/p1/a.mp3',
        'assets/praises/p1/m1.gestures',
      ]) {
        expect(isLegacyPdfId(encodePdfId(path)), isFalse, reason: path);
      }
    });

    test('não-PDF, letra, YouTube e lixo não são legados', () {
      expect(isLegacyPdfId(encodePdfId('ColAdultos/001.chord')), isFalse);
      expect(isLegacyPdfId('lyrics:p1'), isFalse);
      expect(isLegacyPdfId('dQw4w9WgXcQ'), isFalse);
      expect(isLegacyPdfId(''), isFalse);
      expect(isLegacyPdfId('não é base64!'), isFalse);
    });
  });

  group('coldigomPdfIdFromAssetUrl', () {
    test('URL absoluta vira encodePdfId do r2Key', () {
      expect(
        coldigomPdfIdFromAssetUrl(
          'https://coldigom.test/assets/praises/p1/m1.pdf',
        ),
        encodePdfId('assets/praises/p1/m1.pdf'),
      );
    });

    test('material movido: vale a pasta da URL', () {
      expect(
        coldigomPdfIdFromAssetUrl(
          'https://coldigom.test/assets/praises/p9/m1.pdf',
        ),
        encodePdfId('assets/praises/p9/m1.pdf'),
      );
    });

    test('percent-encoding é decodificado antes de codificar', () {
      expect(
        coldigomPdfIdFromAssetUrl(
          'https://coldigom.test/assets/praises/p9/m%202.pdf',
        ),
        'YXNzZXRzL3ByYWlzZXMvcDkvbSAyLnBkZg',
      );
    });

    test('query string e fragment são descartados antes do path (6.7)', () {
      expect(
        coldigomPdfIdFromAssetUrl('https://host/assets/praises/p/m.pdf?v=2#x'),
        coldigomPdfIdFromAssetUrl('https://host/assets/praises/p/m.pdf'),
      );
    });

    test('sem assets/praises/<praise>/<ficheiro> devolve null', () {
      expect(
        coldigomPdfIdFromAssetUrl('https://coldigom.test/outra/coisa.pdf'),
        isNull,
      );
      expect(
        coldigomPdfIdFromAssetUrl('https://coldigom.test/assets/praises/'),
        isNull,
      );
      expect(
        coldigomPdfIdFromAssetUrl('https://coldigom.test/assets/praises/p1'),
        isNull,
      );
      expect(
        coldigomPdfIdFromAssetUrl(
          'https://coldigom.test/assets/praises/p1/%E0%A4%A.pdf',
        ),
        isNull,
      );
      expect(coldigomPdfIdFromAssetUrl('001.pdf'), isNull);
      expect(coldigomPdfIdFromAssetUrl(''), isNull);
    });
  });
}
