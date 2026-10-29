import 'package:coldigui/features/carousel/presentation/widgets/carousel_clear_choice_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<CarouselClearChoice?> openDialog(
    WidgetTester tester, {
    required bool canDelete,
  }) async {
    CarouselClearChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showCarouselClearChoiceDialog(
                    context,
                    canDelete: canDelete,
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('sem Apagar: Cancelar e Nova Lista; meio permanece', (
    tester,
  ) async {
    await openDialog(tester, canDelete: false);

    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Nova Lista'), findsOneWidget);
    expect(find.text('Apagar lista'), findsNothing);

    await tester.tap(find.text('Nova Lista'));
    await tester.pumpAndSettle();
  });

  testWidgets('com Apagar: três opções e deleteList', (tester) async {
    CarouselClearChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showCarouselClearChoiceDialog(
                    context,
                    canDelete: true,
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Nova Lista'), findsOneWidget);
    expect(find.text('Apagar lista'), findsOneWidget);

    await tester.tap(find.text('Apagar lista'));
    await tester.pumpAndSettle();

    expect(result, CarouselClearChoice.deleteList);
  });

  testWidgets('Cancelar fecha sem escolha', (tester) async {
    CarouselClearChoice? result = CarouselClearChoice.newList;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showCarouselClearChoiceDialog(
                    context,
                    canDelete: true,
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
