import '../../../support/fakes/fake_playlists_notifier.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/active_playlist_name_chip.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final salvaItem = PlaylistViewItem(
    playlist: SavedPlaylist.fromLegacyLists(
      playlistId: 'p1',
      nome: 'Ensaio domingo',
      pdfIds: const ['a'],
      createdAt: DateTime(2026, 6, 8),
    ),
    pdfLabels: const ['001 — A'],
  );

  final draftItem = PlaylistViewItem(
    playlist: SavedPlaylist.fromLegacyLists(
      playlistId: 'p2',
      nome: 'lista 08/06/2026 10:00:00',
      pdfIds: const ['a'],
      createdAt: DateTime(2026, 6, 8),
      salva: false,
    ),
    pdfLabels: const ['001 — A'],
  );

  Future<FakePlaylistsNotifier> pumpChip(
    WidgetTester tester, {
    required List<PlaylistViewItem> items,
    String? activeId,
  }) async {
    SharedPreferences.setMockInitialValues(
      activeId == null ? {} : {kActivePlaylistIdPrefsKey: activeId},
    );
    final prefs = await SharedPreferences.getInstance();
    final notifier = FakePlaylistsNotifier(items);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistsProvider.overrideWith(() => notifier),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('pt'),
          home: Scaffold(body: ActivePlaylistNameChip()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('mostra o nome da lista ativa salva', (tester) async {
    await pumpChip(tester, items: [salvaItem], activeId: 'p1');

    expect(find.text('Ensaio domingo'), findsOneWidget);
    expect(find.text('Rascunho'), findsNothing);
  });

  testWidgets('rascunho mostra o rótulo de rascunho, não o nome técnico', (
    tester,
  ) async {
    await pumpChip(tester, items: [draftItem], activeId: 'p2');

    expect(find.text('Rascunho'), findsOneWidget);
    expect(find.text('lista 08/06/2026 10:00:00'), findsNothing);
  });

  testWidgets('sem lista ativa não mostra nada', (tester) async {
    await pumpChip(tester, items: [salvaItem]);

    expect(find.text('Ensaio domingo'), findsNothing);
    expect(find.text('Rascunho'), findsNothing);
    expect(tester.getSize(find.byType(ActivePlaylistNameChip)), Size.zero);
  });

  testWidgets('toque abre o diálogo de renomear e chama rename', (
    tester,
  ) async {
    final notifier = await pumpChip(tester, items: [salvaItem], activeId: 'p1');

    await tester.tap(find.text('Ensaio domingo'));
    await tester.pumpAndSettle();

    expect(find.text('Renomear lista'), findsOneWidget);
    expect(find.text('Ensaio domingo'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Ensaio quarta');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(notifier.renamed, [('p1', 'Ensaio quarta')]);
  });
}
