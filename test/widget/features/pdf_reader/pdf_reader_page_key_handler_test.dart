import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_page_key_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // Sem `pdfId` na rota o handler não tem louvor vizinho para onde ir, então
    // as teclas de carousel viram no-op — é o que estes casos medem.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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

  testWidgets('Espaço navega para próxima página', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(navigated, [3]);
  });

  testWidgets('Shift+Espaço navega para página anterior', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 3,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(navigated, [2]);
  });

  testWidgets('PageDown navega para próxima página', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();

    expect(navigated, [3]);
  });

  testWidgets('Home e End vão aos extremos do documento', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 3,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();

    expect(navigated, [1, 5]);
  });

  testWidgets('ArrowRight na última página não vira página', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 5,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(navigated, isEmpty);
  });

  testWidgets('Ctrl+Espaço não vira página (fica para o play/pause)', (
    tester,
  ) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
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
