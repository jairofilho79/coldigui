import '../../../helpers/legacy_ids_normalizer_test_helpers.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/social/domain/entities/public_playlist.dart';
import 'package:coldigui/features/social/domain/entities/social_user.dart';
import 'package:coldigui/features/social/presentation/providers/social_search_provider.dart';
import 'package:coldigui/features/social/presentation/widgets/social_user_card.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registra o que o import social manda para a lista ativa.
class _RecordingActiveEditor extends ActivePlaylistEditor {
  List<PlaylistEntry>? received;

  @override
  List<PlaylistEntry>? build() => null;

  @override
  Future<int> addEntriesToActive(List<PlaylistEntry> entries) async {
    received = entries;
    return entries.length;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Ordem intercalada, com áudio no meio e o mesmo PDF duas vezes — é a
  // reunião como o dono publicou, e é assim que ela tem que chegar.
  const entries = [
    PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf),
    PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio),
    PlaylistEntry(id: 'pdf-b', kind: MaterialKind.pdf),
    PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf),
  ];

  const playlist = PublicPlaylist(
    id: 'pub-1',
    nome: 'Culto de domingo',
    entries: entries,
    publicationCategory: PlaylistCategory.evangelizacao,
  );

  Future<void> importPlaylist(
    WidgetTester tester,
    PublicPlaylist playlist, {
    required _RecordingActiveEditor editor,
    required FakePlaylistsNotifier playlists,
    required CountingLegacyMaterialIdsNormalizer normalizer,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistsProvider.overrideWith(() => playlists),
          activePlaylistEditorProvider.overrideWith(() => editor),
          noOpLegacyMaterialIdsNormalizerOverride(normalizer),
          socialUserPlaylistsProvider.overrideWith(
            (ref, username) async => [playlist],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(
            body: SocialUserCard(
              user: SocialUser(username: 'maria', playlistCount: 1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('@maria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(playlist.nome));
    await tester.pumpAndSettle();
  }

  testWidgets('import social adiciona partituras e áudios na ordem', (
    tester,
  ) async {
    final editor = _RecordingActiveEditor();
    final playlists = FakePlaylistsNotifier();
    final normalizer = CountingLegacyMaterialIdsNormalizer();

    await importPlaylist(
      tester,
      playlist,
      editor: editor,
      playlists: playlists,
      normalizer: normalizer,
    );

    expect(editor.received, entries);
    expect(playlists.addedPdfIds, isEmpty);
    // A contagem é das entradas (4), não só das partituras (3).
    expect(find.text('4 louvores adicionados à sua lista'), findsOneWidget);
    expect(normalizer.runs, 0, reason: 'sem ids legados');
  });

  testWidgets('lista pública com id legado pede a normalização', (
    tester,
  ) async {
    // Um dono com cliente antigo publicou antes do script D1 (spec
    // fim-fonte-plpcg §6.2): o id legado entra na lista ativa e só a
    // normalização o troca pelo coldigom.
    final legacy = PublicPlaylist(
      id: 'pub-2',
      nome: 'Ensaio',
      entries: [
        PlaylistEntry(
          id: encodePdfId('ColAdultos/001.pdf'),
          kind: MaterialKind.pdf,
        ),
      ],
      publicationCategory: PlaylistCategory.evangelizacao,
    );
    final normalizer = CountingLegacyMaterialIdsNormalizer();

    await importPlaylist(
      tester,
      legacy,
      editor: _RecordingActiveEditor(),
      playlists: FakePlaylistsNotifier(),
      normalizer: normalizer,
    );

    expect(normalizer.runs, 1);
  });
}
