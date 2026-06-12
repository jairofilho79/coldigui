import 'package:coldigui/features/playlists/presentation/widgets/import_playlist_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showImportPlaylistDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('importa URL válida', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'https://plpcg.com/?sharepdfs=a%2Cb&sharename=Ensaio',
    );
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('exibe erro para URL inválida', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'https://example.com');
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Link inválido'), findsOneWidget);
  });
}
