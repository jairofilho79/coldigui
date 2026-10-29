import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_page_jump_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfPageJumpPolicy.landingPage', () {
    test('página vizinha anima direto (sem salto)', () {
      expect(
        PdfPageJumpPolicy.landingPage(from: 5, to: 6, pageCount: 16),
        isNull,
      );
      expect(
        PdfPageJumpPolicy.landingPage(from: 5, to: 4, pageCount: 16),
        isNull,
      );
    });

    test('mesma página não salta', () {
      expect(
        PdfPageJumpPolicy.landingPage(from: 7, to: 7, pageCount: 16),
        isNull,
      );
    });

    test('subindo de longe pousa na vizinha de baixo do destino', () {
      expect(PdfPageJumpPolicy.landingPage(from: 16, to: 1, pageCount: 16), 2);
      expect(PdfPageJumpPolicy.landingPage(from: 10, to: 3, pageCount: 16), 4);
    });

    test('descendo de longe pousa na vizinha de cima do destino', () {
      expect(PdfPageJumpPolicy.landingPage(from: 1, to: 16, pageCount: 16), 15);
      expect(PdfPageJumpPolicy.landingPage(from: 3, to: 5, pageCount: 16), 4);
    });

    test('documento de uma página nunca salta', () {
      expect(
        PdfPageJumpPolicy.landingPage(from: 1, to: 1, pageCount: 1),
        isNull,
      );
      expect(
        PdfPageJumpPolicy.landingPage(from: 1, to: 5, pageCount: 1),
        isNull,
      );
    });

    test('sem páginas (documento ainda sem contagem) não salta', () {
      expect(
        PdfPageJumpPolicy.landingPage(from: 1, to: 9, pageCount: 0),
        isNull,
      );
    });

    test('destino fora do intervalo é tratado como a página da borda', () {
      // pdfrx clampa o `goToPage` na borda — a distância conta a partir dela.
      expect(PdfPageJumpPolicy.landingPage(from: 1, to: 99, pageCount: 16), 15);
      expect(PdfPageJumpPolicy.landingPage(from: 16, to: -3, pageCount: 16), 2);
      expect(
        PdfPageJumpPolicy.landingPage(from: 15, to: 99, pageCount: 16),
        isNull,
      );
    });

    test('origem fora do intervalo é tratada como a página da borda', () {
      expect(
        PdfPageJumpPolicy.landingPage(from: 0, to: 2, pageCount: 16),
        isNull,
      );
      expect(PdfPageJumpPolicy.landingPage(from: 0, to: 9, pageCount: 16), 8);
      expect(PdfPageJumpPolicy.landingPage(from: 40, to: 1, pageCount: 16), 2);
    });

    test('pouso fica sempre dentro do documento', () {
      for (var from = 1; from <= 6; from++) {
        for (var to = 1; to <= 6; to++) {
          final landing = PdfPageJumpPolicy.landingPage(
            from: from,
            to: to,
            pageCount: 6,
          );
          if (landing == null) {
            expect((to - from).abs(), lessThanOrEqualTo(1));
            continue;
          }
          expect(landing, inInclusiveRange(1, 6));
          expect((landing - to).abs(), 1);
          // Do lado de onde se vem: entre a origem e o destino.
          expect((landing - from).abs(), lessThan((to - from).abs()));
        }
      }
    });
  });

  test('trecho final do salto dura 350 ms', () {
    expect(
      PdfPageJumpPolicy.finalLegDuration,
      const Duration(milliseconds: 350),
    );
  });
}
