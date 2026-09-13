import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/presentation/widgets/playlist_share_sheet.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exibe Folheto e Só o link, nesta ordem, e devolve a opção',
      (tester) async {
    PlaylistShareOption? selected;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  selected = await showPlaylistShareSheet(context);
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

    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.text('Folheto'), findsOneWidget);
    expect(find.text('Só o link'), findsOneWidget);
    expect(find.text('Só o folheto'), findsNothing);
    expect(find.text('Link com folheto'), findsNothing);
    expect(find.text('Link + folheto'), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(2));

    final folhetoY = tester.getTopLeft(find.text('Folheto')).dy;
    final linkY = tester.getTopLeft(find.text('Só o link')).dy;
    expect(folhetoY, lessThan(linkY));

    await tester.tap(find.text('Folheto'));
    await tester.pumpAndSettle();
    expect(selected, PlaylistShareOption.linkWithLeaflet);
  });

  testWidgets('Só o link devolve PlaylistShareOption.link', (tester) async {
    PlaylistShareOption? selected;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  selected = await showPlaylistShareSheet(context);
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
    await tester.tap(find.text('Só o link'));
    await tester.pumpAndSettle();
    expect(selected, PlaylistShareOption.link);
  });
}
