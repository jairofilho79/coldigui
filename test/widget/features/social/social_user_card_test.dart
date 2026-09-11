import 'package:coldigui/core/providers/shared_prefs_provider.dart';
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

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  final addedPdfIds = <String>[];

  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<bool> addLouvorToActivePlaylist(String pdfId) async {
    addedPdfIds.add(pdfId);
    return true;
  }
}

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

  testWidgets('import social adiciona partituras e áudios na ordem', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final editor = _RecordingActiveEditor();
    final playlists = _FakePlaylistsNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistsProvider.overrideWith(() => playlists),
          activePlaylistEditorProvider.overrideWith(() => editor),
          socialUserPlaylistsProvider.overrideWith(
            (ref, username) async => const [playlist],
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

    // A contagem é das entradas (4), não só das partituras (3).
    expect(find.text('4 louvores'), findsOneWidget);

    await tester.tap(find.text('Culto de domingo'));
    await tester.pumpAndSettle();

    expect(editor.received, entries);
    expect(playlists.addedPdfIds, isEmpty);
    expect(find.text('4 louvores adicionados à sua lista'), findsOneWidget);
  });
}
