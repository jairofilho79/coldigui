import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_page_edge_tap_policy.dart';
import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_page_swipe_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const canvasWidth = 500.0;
  const edgeWidth = canvasWidth * kPdfPageEdgeTapZoneFraction; // 100

  group('PdfPageEdgeTapPolicy.directionForDownPosition', () {
    test('10% da largura mapeia para previous', () {
      expect(
        PdfPageEdgeTapPolicy.directionForDownPosition(
          localX: canvasWidth * 0.1,
          canvasWidth: canvasWidth,
        ),
        PdfPageSwipeDirection.previous,
      );
    });

    test('90% da largura mapeia para next', () {
      expect(
        PdfPageEdgeTapPolicy.directionForDownPosition(
          localX: canvasWidth * 0.9,
          canvasWidth: canvasWidth,
        ),
        PdfPageSwipeDirection.next,
      );
    });

    test('50% da largura retorna null (centro)', () {
      expect(
        PdfPageEdgeTapPolicy.directionForDownPosition(
          localX: canvasWidth * 0.5,
          canvasWidth: canvasWidth,
        ),
        isNull,
      );
    });

    test('exatamente no limite esquerdo (20%) retorna null', () {
      expect(
        PdfPageEdgeTapPolicy.directionForDownPosition(
          localX: edgeWidth,
          canvasWidth: canvasWidth,
        ),
        isNull,
      );
    });

    test('justamente dentro da zona esquerda retorna previous', () {
      expect(
        PdfPageEdgeTapPolicy.directionForDownPosition(
          localX: edgeWidth - 0.01,
          canvasWidth: canvasWidth,
        ),
        PdfPageSwipeDirection.previous,
      );
    });

    test('exatamente no limite direito (80%) retorna null', () {
      expect(
        PdfPageEdgeTapPolicy.directionForDownPosition(
          localX: canvasWidth - edgeWidth,
          canvasWidth: canvasWidth,
        ),
        isNull,
      );
    });

    test('justamente dentro da zona direita retorna next', () {
      expect(
        PdfPageEdgeTapPolicy.directionForDownPosition(
          localX: canvasWidth - edgeWidth + 0.01,
          canvasWidth: canvasWidth,
        ),
        PdfPageSwipeDirection.next,
      );
    });

    test('canvasWidth inválido retorna null', () {
      expect(
        PdfPageEdgeTapPolicy.directionForDownPosition(
          localX: 10,
          canvasWidth: 0,
        ),
        isNull,
      );
    });
  });

  group('PdfPageEdgeTapPolicy.isStrictTap', () {
    test('(3, 2) é toque estrito', () {
      expect(PdfPageEdgeTapPolicy.isStrictTap(const Offset(3, 2)), isTrue);
    });

    test('(7, 0) é toque estrito', () {
      expect(PdfPageEdgeTapPolicy.isStrictTap(const Offset(7, 0)), isTrue);
    });

    test('(8, 0) não é toque estrito', () {
      expect(PdfPageEdgeTapPolicy.isStrictTap(const Offset(8, 0)), isFalse);
    });

    test('(0, 10) não é toque estrito', () {
      expect(PdfPageEdgeTapPolicy.isStrictTap(const Offset(0, 10)), isFalse);
    });

    test('Offset.zero é toque estrito', () {
      expect(PdfPageEdgeTapPolicy.isStrictTap(Offset.zero), isTrue);
    });
  });
}
