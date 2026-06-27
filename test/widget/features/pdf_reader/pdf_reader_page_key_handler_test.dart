import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_page_key_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHandler(
    WidgetTester tester, {
    required int currentPage,
    required int pagesCount,
    required bool enabled,
    required bool pageTurnInProgress,
    required List<int> navigatedPages,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfReaderPageKeyHandler(
            currentPage: currentPage,
            pagesCount: pagesCount,
            enabled: enabled,
            pageTurnInProgress: pageTurnInProgress,
            onNavigateToPage: (page) async {
              navigatedPages.add(page);
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('ArrowRight navega para próxima página', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(navigated, [3]);
  });

  testWidgets('ArrowUp navega para página anterior', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 3,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(navigated, [2]);
  });

  testWidgets('ArrowLeft na primeira página não navega', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 1,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(navigated, isEmpty);
  });

  testWidgets('ArrowUp na primeira página não navega', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 1,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(navigated, isEmpty);
  });

  testWidgets('ignora teclas quando pageTurnInProgress', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: true,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(navigated, isEmpty);
  });

  testWidgets('ignora teclas quando enabled é false', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: false,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(navigated, isEmpty);
  });
}
