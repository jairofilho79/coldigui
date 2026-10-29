import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_overrides.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: standardTestOverrides(prefs: prefs),
    );
    addTearDown(container.dispose);
  });

  test('sem projeção, activeEntries vem da lista ativa local (vazia aqui)', () {
    expect(container.read(activeEntriesProvider), isEmpty);
  });

  test('com projeção, activeEntries são as entradas do gestor com chaves por ocorrência', () {
    container
        .read(liveProjectionProvider.notifier)
        .set(
          LiveProjection(
            ownerName: 'Fulano',
            playlistId: 'p1',
            name: 'Culto',
            entries: const [
              PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
              PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
              PlaylistEntry(id: 't', kind: MaterialKind.audio),
            ],
          ),
        );
    final entries = container.read(activeEntriesProvider);
    expect(entries.map((e) => e.key), ['a', 'a#1', 't']);
    expect(
      container.read(activePlaylistEditorProvider.notifier).isFollowingLive,
      isTrue,
    );
  });

  test('mutações da lista ativa são ignoradas enquanto segue', () async {
    container
        .read(liveProjectionProvider.notifier)
        .set(
          LiveProjection(
            ownerName: 'Fulano',
            playlistId: 'p1',
            name: 'Culto',
            entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
          ),
        );
    final editor = container.read(activePlaylistEditorProvider.notifier);
    expect(await editor.addToActive('zzz'), AddToActiveOutcome.following);
    expect(
      await editor.addEntriesToActive(const [
        PlaylistEntry(id: 'b', kind: MaterialKind.pdf),
      ]),
      0,
    );
    await editor.removeByKey('a');
    await editor.reorder(const ['a']);
    expect(container.read(activeEntriesProvider).map((e) => e.key), ['a']);
  });

  test('clear() devolve a lista ativa local', () {
    final notifier = container.read(liveProjectionProvider.notifier);
    notifier.set(
      LiveProjection(
        ownerName: 'F',
        playlistId: 'p',
        name: 'n',
        entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      ),
    );
    notifier.clear();
    expect(container.read(activeEntriesProvider), isEmpty);
    expect(
      container.read(activePlaylistEditorProvider.notifier).isFollowingLive,
      isFalse,
    );
  });
}
