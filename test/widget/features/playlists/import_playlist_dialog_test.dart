import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/playlists/presentation/widgets/import_playlist_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PlaylistShareParams? result;

  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showImportPlaylistDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> submit(WidgetTester tester, String text) async {
    result = null;
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
  }

  testWidgets('link por praise fecha o diálogo com os tokens', (tester) async {
    await submit(tester, 'https://v2.plpcg.com/?p=0a1-fff&n=Ensaio');

    expect(find.text('open'), findsOneWidget);
    expect(result?.praiseShortIds, ['0a1', 'fff']);
    expect(result?.shareName, 'Ensaio');
  });

  testWidgets('link antigo fecha o diálogo com params antigos', (tester) async {
    await submit(tester, 'https://plpcg.com/?sharepdfs=a%2Cb&sharename=Ensaio');

    expect(find.text('open'), findsOneWidget);
    expect(result?.isLegacy, isTrue);
  });

  testWidgets('exibe erro para URL que não é link de lista', (tester) async {
    await submit(tester, 'https://example.com');

    expect(find.textContaining('Link inválido'), findsOneWidget);
    expect(result, isNull);
  });
}
