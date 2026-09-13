import 'dart:async';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/providers/carousel_providers.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_hydrate.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlaylistRepo extends Fake implements PlaylistRepository {
  _FakePlaylistRepo(this.playlist);

  final SavedPlaylist? playlist;

  @override
  Future<SavedPlaylist?> getById(String playlistId) async => playlist;
}

/// Ids realistas: `audioId` é sempre `encodePdfId(r2Key)` — é a extensão do
/// path que faz `materialIdKindOf` classificar o material como áudio, e é
/// disso que `SavedPlaylist.audioIds` deriva.
final _audioIdA = encodePdfId('assets/praises/p1/a.mp3');
final _audioIdB = encodePdfId('assets/praises/p1/b.mp3');

final _trackA = AudioTrack(
  audioId: _audioIdA,
  r2Key: 'assets/praises/p1/a.mp3',
  nome: 'Shekinah',
  numero: '047',
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'Coro',
);

final _trackB = AudioTrack(
  audioId: _audioIdB,
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

  Future<bool> run() => hydratePlaylistSession(ref);
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

  test('restoreQueueStartIndex usa o audioId persistido', () {
    expect(restoreQueueStartIndex([_trackA, _trackB], _audioIdB), 1);
    expect(restoreQueueStartIndex([_trackA, _trackB], 'missing'), 0);
    expect(restoreQueueStartIndex(const [], _audioIdB), 0);
  });

  test('hydrate restaura fila pausada no audioId persistido', () async {
    SharedPreferences.setMockInitialValues({
      kActivePlaylistIdPrefsKey: 'pl-1',
      kPlaylistFocusedAudioIdPrefsKey: _audioIdB,
    });
    final prefs = await SharedPreferences.getInstance();
    final playlist = SavedPlaylist.fromLegacyLists(
      playlistId: 'pl-1',
      nome: 'Ensaio',
      pdfIds: const [],
      audioIds: [_audioIdA, _audioIdB],
      createdAt: DateTime(2026, 1, 1),
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarStatusProvider.overrideWithValue(IsarStatus.available),
        playlistRepositoryProvider.overrideWithValue(
          _FakePlaylistRepo(playlist),
        ),
        carouselLocalDatasourceProvider.overrideWithValue(
          const CarouselLocalDatasource.unavailable(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
      _trackA,
      _trackB,
    ]);

    expect(await container.read(_hydrateRunnerProvider.notifier).run(), isTrue);

    final session = container.read(audioPlayerSessionProvider);
    expect(session.queue.map((t) => t.audioId), [_audioIdA, _audioIdB]);
    expect(session.currentIndex, 1);
    expect(session.playing, isFalse);
  });

  group('sem storage a hidratação não apaga estado persistido', () {
    /// Estado de um boot real com playlist ativa de áudio salva nas prefs.
    Future<SharedPreferences> bootPrefs() async {
      SharedPreferences.setMockInitialValues({
        kActivePlaylistIdPrefsKey: 'pl-1',
      });
      return SharedPreferences.getInstance();
    }

    /// Datasource degradado: `getById` devolve `null` para qualquer id, sem
    /// distinguir "não existe" de "o banco não abriu".
    ProviderContainer degradedContainer(
      SharedPreferences prefs,
      List<Override> isarOverrides,
    ) {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...isarOverrides,
          playlistRepositoryProvider.overrideWithValue(_FakePlaylistRepo(null)),
          carouselLocalDatasourceProvider.overrideWithValue(
            CarouselLocalDatasource.unavailable(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    void expectUntouched(ProviderContainer container, SharedPreferences prefs) {
      expect(
        prefs.getString(kActivePlaylistIdPrefsKey),
        'pl-1',
        reason: 'o id da playlist ativa é permanente — apagar é irreversível',
      );
      expect(container.read(activePlaylistIdProvider), 'pl-1');
    }

    test('Isar indisponível', () async {
      final prefs = await bootPrefs();
      final container = degradedContainer(prefs, [
        isarStatusProvider.overrideWithValue(IsarStatus.unavailable),
      ]);

      expect(
        await container.read(_hydrateRunnerProvider.notifier).run(),
        isFalse,
        reason: 'sem storage a hidratação não aconteceu',
      );

      expectUntouched(container, prefs);
    });

    test('Isar abrindo que termina em falha', () async {
      final prefs = await bootPrefs();
      final opening = Completer<Isar>();
      final container = degradedContainer(prefs, [
        isarOpenerProvider.overrideWithValue(() => opening.future),
      ]);

      final hydrating = container.read(_hydrateRunnerProvider.notifier).run();
      opening.completeError(StateError('OPFS travado'));

      expect(await hydrating, isFalse);
      expectUntouched(container, prefs);
    });
  });
}
