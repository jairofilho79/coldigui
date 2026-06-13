import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_page_swipe_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfPageSwipePolicy.hasHorizontalPanRoom', () {
    test('sem pan quando página cabe na largura do viewport', () {
      expect(
        PdfPageSwipePolicy.hasHorizontalPanRoom(
          pageRect: const Rect.fromLTWH(10, 0, 200, 800),
          zoomRatio: 1.0,
          viewWidth: 400,
        ),
        isFalse,
      );
    });

    test('com pan quando página zoomada é mais larga que o viewport', () {
      expect(
        PdfPageSwipePolicy.hasHorizontalPanRoom(
          pageRect: const Rect.fromLTWH(10, 0, 500, 800),
          zoomRatio: 2.0,
          viewWidth: 400,
        ),
        isTrue,
      );
    });
  });

  group('PdfPageSwipePolicy.isAtHorizontalEdge', () {
    test('borda direita quando viewport encosta no fim da página', () {
      final transform = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-620, 0, 0);

      expect(
        PdfPageSwipePolicy.isAtHorizontalEdge(
          transform: transform,
          pageRect: const Rect.fromLTWH(10, 0, 500, 800),
          viewWidth: 400,
          trailingEdge: true,
        ),
        isTrue,
      );
    });

    test('não está na borda direita quando ainda há pan horizontal', () {
      final transform = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-100, 0, 0);

      expect(
        PdfPageSwipePolicy.isAtHorizontalEdge(
          transform: transform,
          pageRect: const Rect.fromLTWH(10, 0, 500, 800),
          viewWidth: 400,
          trailingEdge: true,
        ),
        isFalse,
      );
    });

    test('borda esquerda quando viewport encosta no início da página', () {
      final transform = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-20, 0, 0);

      expect(
        PdfPageSwipePolicy.isAtHorizontalEdge(
          transform: transform,
          pageRect: const Rect.fromLTWH(10, 0, 500, 800),
          viewWidth: 400,
          trailingEdge: false,
        ),
        isTrue,
      );
    });
  });

  group('PdfPageSwipePolicy.isHorizontalSwipe', () {
    test('aceita deslocamento horizontal dominante acima do mínimo', () {
      expect(
        PdfPageSwipePolicy.isHorizontalSwipe(const Offset(60, 10)),
        isTrue,
      );
    });

    test('rejeita deslocamento abaixo do mínimo', () {
      expect(
        PdfPageSwipePolicy.isHorizontalSwipe(const Offset(30, 5)),
        isFalse,
      );
    });

    test('rejeita gesto predominantemente vertical', () {
      expect(
        PdfPageSwipePolicy.isHorizontalSwipe(const Offset(50, 80)),
        isFalse,
      );
    });
  });

  group('PdfPageSwipePolicy.activeHorizontalSwipe', () {
    test('retorna next para swipe direita→esquerda válido', () {
      expect(
        PdfPageSwipePolicy.activeHorizontalSwipe(const Offset(-60, 10)),
        PdfPageSwipeDirection.next,
      );
    });

    test('retorna previous para swipe esquerda→direita válido', () {
      expect(
        PdfPageSwipePolicy.activeHorizontalSwipe(const Offset(60, 10)),
        PdfPageSwipeDirection.previous,
      );
    });

    test('retorna null abaixo do threshold horizontal', () {
      expect(
        PdfPageSwipePolicy.activeHorizontalSwipe(const Offset(30, 5)),
        isNull,
      );
    });

    test('retorna null para gesto predominantemente vertical', () {
      expect(
        PdfPageSwipePolicy.activeHorizontalSwipe(const Offset(50, 80)),
        isNull,
      );
    });
  });

  group('PdfPageSwipePolicy.minHorizontalDx', () {
    test('expõe o mesmo valor de kPdfPageSwipeMinDistance', () {
      expect(
        PdfPageSwipePolicy.minHorizontalDx,
        kPdfPageSwipeMinDistance,
      );
    });
  });
}
