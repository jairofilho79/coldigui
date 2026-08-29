import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/domain/repositories/carousel_repository.dart';
import 'package:coldigui/features/carousel/data/providers/carousel_providers.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_hydrate.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlaylistRepo extends Fake implements PlaylistRepository {
  _FakePlaylistRepo(this.playlist);

  final SavedPlaylist? playlist;

  @override
  Future<SavedPlaylist?> getById(String playlistId) async => playlist;
}

class _FakeCarouselRepo extends Fake implements CarouselRepository {
  @override
  Future<List<String>> getOrderedPdfIds() async => const [];
}

const _trackA = AudioTrack(
  audioId: 'aud-a',
  r2Key: 'assets/praises/p1/a.mp3',
  nome: 'Shekinah',
  numero: '047',
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'Coro',
);

const _trackB = AudioTrack(
  audioId: 'aud-b',
  r2Key: 'assets/praises/p1/b.mp3',
  nome: 'Shekinah',
  numero: '047',
  groupId: 'p1',
  categoria: 'Playback',
  classificacao: 'Coro',
);

class _HydrateRunner extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> run() => hydratePlaylistSession(ref);
}

final _hydrateRunnerProvider = NotifierProvider<_HydrateRunner, int>(
  _HydrateRunner.new,
);

void main() {
  test('collectColdigomPraiseIds lê pdfId e audioId', () {
    final pdfId = encodePdfId('assets/praises/p1/part.pdf');
    final audioId = encodePdfId('assets/praises/p1/a.mp3');
    expect(collectColdigomPraiseIds(pdfIds: [pdfId], audioIds: [audioId]), {
      'p1',
    });
  });

  test('tracksForAudioIds preserva a ordem e ignora miss', () {
    expect(
      tracksForAudioIds(
        ['aud-b', 'missing', 'aud-a'],
        {'aud-a': _trackA, 'aud-b': _trackB},
      ).map((t) => t.audioId),
      ['aud-b', 'aud-a'],
    );
  });

  test('restoreQueueStartIndex usa o audioId persistido', () {
    expect(restoreQueueStartIndex(const [_trackA, _trackB], 'aud-b'), 1);
    expect(restoreQueueStartIndex(const [_trackA, _trackB], 'missing'), 0);
    expect(restoreQueueStartIndex(const [], 'aud-b'), 0);
  });

  test('hydrate restaura fila pausada no audioId persistido', () async {
    SharedPreferences.setMockInitialValues({
      kActivePlaylistIdPrefsKey: 'pl-1',
      kPlaylistFocusedAudioIdPrefsKey: 'aud-b',
      'playlist_media_face': PlaylistMediaFace.audio.name,
    });
    final prefs = await SharedPreferences.getInstance();
    final playlist = SavedPlaylist(
      playlistId: 'pl-1',
      nome: 'Ensaio',
      pdfIds: const [],
      audioIds: const ['aud-a', 'aud-b'],
      createdAt: DateTime(2026, 1, 1),
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        playlistRepositoryProvider.overrideWithValue(
          _FakePlaylistRepo(playlist),
        ),
        carouselRepositoryProvider.overrideWithValue(_FakeCarouselRepo()),
      ],
    );
    addTearDown(container.dispose);

    container.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks(
      const [_trackA, _trackB],
    );

    await container.read(_hydrateRunnerProvider.notifier).run();

    final session = container.read(audioPlayerSessionProvider);
    expect(session.queue.map((t) => t.audioId), ['aud-a', 'aud-b']);
    expect(session.currentIndex, 1);
    expect(session.playing, isFalse);
  });
}
