import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_render_scale_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfRenderScalePolicy.resolve — min(estimada, 2×DPR, 3.0)', () {
    test('estimativa abaixo dos dois tetos passa intacta', () {
      expect(
        PdfRenderScalePolicy.resolve(estimatedScale: 2.5, devicePixelRatio: 3),
        2.5,
      );
    });

    test('tela de alto DPR bate no teto absoluto 3.0', () {
      expect(
        PdfRenderScalePolicy.resolve(estimatedScale: 8, devicePixelRatio: 3),
        3.0,
      );
    });

    test('tela 1× (desktop) bate no teto por DPR (2×1)', () {
      expect(
        PdfRenderScalePolicy.resolve(estimatedScale: 3, devicePixelRatio: 1),
        2.0,
      );
    });

    test('tela 1.5× — os dois tetos coincidem em 3.0', () {
      expect(
        PdfRenderScalePolicy.resolve(estimatedScale: 4, devicePixelRatio: 1.5),
        3.0,
      );
    });

    test('constantes da spec §2.3', () {
      expect(PdfRenderScalePolicy.ceiling, 3.0);
      expect(PdfRenderScalePolicy.dprMultiplier, 2);
    });
  });
}
