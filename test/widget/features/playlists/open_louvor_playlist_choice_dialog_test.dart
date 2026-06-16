import 'package:coldigui/features/playlists/presentation/widgets/open_louvor_playlist_choice_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showOpenLouvorPlaylistChoiceDialog(context),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('fechar modal não abre leitor', (tester) async {
    await openDialog(tester);

    expect(find.text('Como adicionar à lista?'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Como adicionar à lista?'), findsNothing);
  });

  testWidgets('adicionar à lista atual fecha com addToCurrent', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Adicionar à lista atual'));
    await tester.pumpAndSettle();

    expect(find.text('Como adicionar à lista?'), findsNothing);
  });

  testWidgets('criar nova lista fecha com createNew', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Criar nova lista'));
    await tester.pumpAndSettle();

    expect(find.text('Como adicionar à lista?'), findsNothing);
  });

  testWidgets('mensagem avisa que lista atual permanece em não salvas',
      (tester) async {
    await openDialog(tester);

    expect(
      find.textContaining('permanecerá em Listas não salvas'),
      findsOneWidget,
    );
  });
}
