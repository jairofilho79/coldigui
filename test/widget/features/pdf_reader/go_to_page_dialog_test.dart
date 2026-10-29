import 'package:coldigui/features/pdf_reader/presentation/widgets/go_to_page_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Botão que abre [GoToPageDialog] e guarda o resultado em [onResult] — o
/// jeito mais simples de exercitar `Navigator.pop<int>` num teste de widget.
class _Harness extends StatelessWidget {
  const _Harness({
    required this.pageCount,
    required this.onResult,
    this.initialPage,
  });

  final int pageCount;
  final int? initialPage;
  final ValueChanged<int?> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                final result = await GoToPageDialog.show(
                  context,
                  pageCount: pageCount,
                  initialPage: initialPage,
                );
                onResult(result);
              },
              child: const Text('abrir'),
            );
          },
        ),
      ),
    );
  }
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  testWidgets('mostra o título l10n ao abrir', (tester) async {
    await tester.pumpWidget(_Harness(pageCount: 5, onResult: (_) {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.readerGoToPageTitle), findsOneWidget);
  });

  testWidgets('digitar 0 desabilita o botão de confirmar', (tester) async {
    await tester.pumpWidget(_Harness(pageCount: 5, onResult: (_) {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.readerGoToPageConfirm),
    );
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets('digitar valor acima do teto desabilita o botão de confirmar', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(pageCount: 5, onResult: (_) {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '6');
    await tester.pump();

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.readerGoToPageConfirm),
    );
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets('digitar 2 e confirmar devolve a página 2', (tester) async {
    int? result;
    await tester.pumpWidget(
      _Harness(pageCount: 5, onResult: (value) => result = value),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();

    await tester.tap(
      find.widgetWithText(FilledButton, l10n.readerGoToPageConfirm),
    );
    await tester.pumpAndSettle();

    expect(result, 2);
  });

  testWidgets('initialPage pré-preenche o campo com o OK já habilitado', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(pageCount: 5, initialPage: 3, onResult: (_) {}),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.readerGoToPageConfirm),
    );
    expect(confirmButton.onPressed, isNotNull);
  });

  testWidgets('cancelar devolve null', (tester) async {
    int? result = -1;
    await tester.pumpWidget(
      _Harness(pageCount: 5, onResult: (value) => result = value),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(TextButton, l10n.readerGoToPageCancel),
    );
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
