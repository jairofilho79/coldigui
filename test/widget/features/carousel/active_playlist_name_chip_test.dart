import '../../../support/fakes/fake_playlists_notifier.dart';
import '../../../support/pump_app.dart';
import '../../../support/test_overrides.dart';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/active_playlist_name_chip.dart';
import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Projecting extends LiveProjectionNotifier {
  @override
  LiveProjection? build() => LiveProjection(
    ownerName: 'Fulano',
    playlistId: 'p',
    name: 'Culto',
    entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
  );
}

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
    double maxWidth = ActivePlaylistNameChip.defaultMaxWidth,
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
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ActivePlaylistNameChip(maxWidth: maxWidth),
            ),
          ),
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

  testWidgets('toque no rascunho salva a lista com o nome, não só renomeia', (
    tester,
  ) async {
    final notifier = await pumpChip(tester, items: [draftItem], activeId: 'p2');

    await tester.tap(find.text('Rascunho'));
    await tester.pumpAndSettle();

    expect(find.text('Salvar lista'), findsOneWidget);
    expect(find.text('Renomear lista'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Culto de quarta');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(notifier.savedActiveNames, ['Culto de quarta']);
    expect(notifier.renamed, isEmpty);
    expect(find.text('Lista salva'), findsOneWidget);
  });

  testWidgets('nome longo respeita maxWidth com reticências', (tester) async {
    final longItem = PlaylistViewItem(
      playlist: SavedPlaylist.fromLegacyLists(
        playlistId: 'p3',
        nome: 'Um nome de lista comprido demais para caber na barra',
        pdfIds: const ['a'],
        createdAt: DateTime(2026, 6, 8),
      ),
      pdfLabels: const ['001 — A'],
    );
    await pumpChip(tester, items: [longItem], activeId: 'p3', maxWidth: 80);

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(find.byType(Text)).width, lessThanOrEqualTo(80));
    // 80 de texto + 10 de padding de cada lado + borda de 2 px.
    expect(
      tester.getSize(find.byType(ActivePlaylistNameChip)).width,
      lessThanOrEqualTo(80 + 20 + 4 + 6),
    );
  });

  test('maxWidthForBar: um quinto da barra entre 72 e 160', () {
    expect(ActivePlaylistNameChip.maxWidthForBar(300), 72);
    expect(ActivePlaylistNameChip.maxWidthForBar(480), 96);
    expect(ActivePlaylistNameChip.maxWidthForBar(1200), 160);
  });

  testWidgets(
    'seguindo: mostra o nome da lista do gestor com ícone ao vivo, sem editar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await pumpApp(
        tester,
        const ActivePlaylistNameChip(),
        overrides: [
          ...standardTestOverrides(prefs: prefs),
          liveProjectionProvider.overrideWith(_Projecting.new),
        ],
      );

      expect(find.text('Culto'), findsOneWidget);
      expect(find.byIcon(Icons.sensors), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsNothing);

      await tester.tap(find.text('Culto'));
      await tester.pumpAndSettle();

      expect(find.text('Renomear lista'), findsNothing);
      expect(find.text('Salvar lista'), findsNothing);
    },
  );
}
