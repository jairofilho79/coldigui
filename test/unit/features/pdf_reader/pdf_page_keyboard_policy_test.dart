import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_page_keyboard_policy.dart';
import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_page_swipe_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfPageKeyboardPolicy.directionForKey', () {
    test('arrowLeft mapeia para previous', () {
      expect(
        PdfPageKeyboardPolicy.directionForKey(LogicalKeyboardKey.arrowLeft),
        PdfPageSwipeDirection.previous,
      );
    });

    test('arrowUp mapeia para previous', () {
      expect(
        PdfPageKeyboardPolicy.directionForKey(LogicalKeyboardKey.arrowUp),
        PdfPageSwipeDirection.previous,
      );
    });

    test('arrowRight mapeia para next', () {
      expect(
        PdfPageKeyboardPolicy.directionForKey(LogicalKeyboardKey.arrowRight),
        PdfPageSwipeDirection.next,
      );
    });

    test('arrowDown mapeia para next', () {
      expect(
        PdfPageKeyboardPolicy.directionForKey(LogicalKeyboardKey.arrowDown),
        PdfPageSwipeDirection.next,
      );
    });

    test('tecla não mapeada retorna null', () {
      expect(
        PdfPageKeyboardPolicy.directionForKey(LogicalKeyboardKey.enter),
        isNull,
      );
    });
  });

  group('PdfPageKeyboardPolicy.targetPage', () {
    test('next avança no meio do documento', () {
      expect(
        PdfPageKeyboardPolicy.targetPage(
          currentPage: 2,
          pagesCount: 5,
          direction: PdfPageSwipeDirection.next,
        ),
        3,
      );
    });

    test('previous volta no meio do documento', () {
      expect(
        PdfPageKeyboardPolicy.targetPage(
          currentPage: 3,
          pagesCount: 5,
          direction: PdfPageSwipeDirection.previous,
        ),
        2,
      );
    });

    test('next na última página retorna null', () {
      expect(
        PdfPageKeyboardPolicy.targetPage(
          currentPage: 5,
          pagesCount: 5,
          direction: PdfPageSwipeDirection.next,
        ),
        isNull,
      );
    });

    test('previous na primeira página retorna null', () {
      expect(
        PdfPageKeyboardPolicy.targetPage(
          currentPage: 1,
          pagesCount: 5,
          direction: PdfPageSwipeDirection.previous,
        ),
        isNull,
      );
    });

    test('pagesCount inválido retorna null', () {
      expect(
        PdfPageKeyboardPolicy.targetPage(
          currentPage: 1,
          pagesCount: 0,
          direction: PdfPageSwipeDirection.next,
        ),
        isNull,
      );
    });
  });
}
