import 'package:coldigui/features/live/presentation/widgets/join_live_room_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? returned;

  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async =>
                  returned = await showJoinLiveRoomDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() => returned = null);

  testWidgets('devolve o código de um link colado', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar numa sala ao vivo'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'https://plpcg.com/ao-vivo/k7x2m9q',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(returned, 'k7x2m9q');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Enter no campo também confirma; código solto vale', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'K7X2M9Q');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(returned, 'k7x2m9q');
  });

  testWidgets('link sem sala mostra erro e não fecha', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'https://example.com');
    await tester.tap(find.widgetWithText(TextButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Link ou código de sala inválido'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(returned, isNull);
  });

  testWidgets('Cancelar devolve null', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(returned, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
