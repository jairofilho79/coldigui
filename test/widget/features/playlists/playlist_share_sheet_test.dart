import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/presentation/widgets/playlist_share_sheet.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exibe quatro opções de compartilhamento', (tester) async {
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
    expect(find.text('Só o link'), findsOneWidget);
    expect(find.text('Só o folheto'), findsOneWidget);
    expect(find.text('Link com folheto'), findsOneWidget);
    expect(find.text('Link + folheto'), findsOneWidget);

    await tester.tap(find.text('Link com folheto'));
    await tester.pumpAndSettle();

    expect(selected, PlaylistShareOption.linkWithLeaflet);
  });
}
