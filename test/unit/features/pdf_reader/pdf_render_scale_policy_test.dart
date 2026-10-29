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

  _fitGroup();
}

// Telas de referência: iPhone 16 Pro Max (440 pt, DPR 3), iPad 10ª (820 pt,
// DPR 2), iPad Pro 13" (1032 pt, DPR 2). Páginas: A4 595 pt (grades
// vetoriais) e ~A5 420 pt (scans). Margem do pdfrx = 8.
void _fitGroup() {
  // Área do PDF no iPhone ≈ 440 × 700 pt (tela menos barras).
  double fit({
    required double viewWidth,
    required double dpr,
    required double pageWidth,
    double viewHeight = 1e-9,
    double? pageHeight,
    double? layoutWidth,
    double margin = 8,
  }) {
    final lw = layoutWidth ?? pageWidth;
    final ph = pageHeight ?? pageWidth * 1.414;
    final lh = ph * lw / pageWidth;
    return PdfRenderScalePolicy.resolveForFit(
      devicePixelRatio: dpr,
      viewWidth: viewWidth,
      viewHeight: viewHeight,
      pageMargin: margin,
      coverScale: viewWidth / (lw + margin * 2),
      pageLayoutWidth: lw,
      pageLayoutHeight: lh,
      pagePointWidth: pageWidth,
      pagePointHeight: ph,
    );
  }

  group('PdfRenderScalePolicy.resolveForFit — prévia no tamanho da tela', () {
    test('A4 no iPhone: ~2,16× em vez do teto 3× (metade dos pixels)', () {
      final s = fit(viewWidth: 440, dpr: 3, pageWidth: 595);
      expect(s, closeTo(2.17, 0.005));
    });

    test('A5 no iPhone: 3,03 passa do teto por <10% e segue a tela', () {
      // Com 3,0 o pdfrx renderizava tiles «real size» a cada parada.
      final s = fit(viewWidth: 440, dpr: 3, pageWidth: 420);
      expect(s, closeTo(3.03, 0.005));
      expect(s, greaterThanOrEqualTo(3 * (440 - 16) / 420));
    });

    test('nunca abaixo da escala exibida no ajuste à largura', () {
      for (final (vw, dpr, pw) in [
        (440.0, 3.0, 595.0),
        (440.0, 3.0, 420.0),
        (820.0, 2.0, 595.0),
        (393.0, 3.0, 612.0),
      ]) {
        final displayed = dpr * (vw - 16) / pw;
        final s = fit(viewWidth: vw, dpr: dpr, pageWidth: pw);
        if (displayed <= PdfRenderScalePolicy.ceiling * 1.1) {
          expect(s, greaterThanOrEqualTo(displayed), reason: '$vw/$dpr/$pw');
        }
      }
    });

    test('iPad Pro com A4 (3,35) passa da tolerância → teto 3,0', () {
      expect(fit(viewWidth: 1032, dpr: 2, pageWidth: 595), 3.0);
    });

    test('iPad com A4 fica abaixo do teto (2,71)', () {
      expect(fit(viewWidth: 820, dpr: 2, pageWidth: 595), closeTo(2.71, 0.005));
    });

    test('página maior no layout que no PDF escala junto', () {
      // Layout com a página a 2× do tamanho natural: cada pt ocupa o dobro.
      final natural = fit(viewWidth: 440, dpr: 1.5, pageWidth: 595);
      final scaled = fit(
        viewWidth: 440,
        dpr: 1.5,
        pageWidth: 297.5,
        layoutWidth: 595,
      );
      expect(scaled, closeTo(natural * 2, 0.02));
    });

    test(
      'ajuste pela altura (padrão pageFit) maior que pela largura vence',
      () {
        // A4 no iPhone em pé, «página inteira»: (700 − 16) / 842 = 0,81 →
        // 2,44×; a página fica mais larga que a tela e, com 2,17×, o pdfrx
        // pedia tiles a cada parada.
        final s = fit(
          viewWidth: 440,
          viewHeight: 700,
          dpr: 3,
          pageWidth: 595,
          pageHeight: 842,
        );
        expect(s, closeTo(2.44, 0.005));
        expect(s, greaterThanOrEqualTo(3 * (700 - 16) / 842));
      },
    );

    test('paisagem: ajuste pela largura continua valendo', () {
      final s = fit(
        viewWidth: 956,
        viewHeight: 300,
        dpr: 1,
        pageWidth: 595,
        pageHeight: 842,
      );
      expect(s, closeTo((956 - 16) / 595, 0.01));
    });

    test('piso 1,0 para viewport minúsculo', () {
      expect(fit(viewWidth: 40, dpr: 1, pageWidth: 595), 1.0);
    });

    test('entradas inválidas caem no teto', () {
      expect(
        PdfRenderScalePolicy.resolveForFit(
          devicePixelRatio: 3,
          viewWidth: 440,
          viewHeight: 700,
          pageMargin: 8,
          coverScale: double.nan,
          pageLayoutWidth: 0,
          pageLayoutHeight: 0,
          pagePointWidth: 0,
          pagePointHeight: 0,
        ),
        PdfRenderScalePolicy.ceiling,
      );
    });

    test('estável: mesmas entradas, mesmo valor (pdfrx compara por ==)', () {
      final a = fit(viewWidth: 440, dpr: 3, pageWidth: 595);
      final b = fit(viewWidth: 440, dpr: 3, pageWidth: 595);
      expect(a, b);
    });
  });
}
