import 'dart:async';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_position_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_chips.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tracks = [
  AudioTrack(
    audioId: 'aud-a',
    r2Key: 'assets/praises/p1/a.mp3',
    nome: 'A',
    numero: '001',
    groupId: 'p1',
    categoria: 'Áudio',
    classificacao: 'Coro',
  ),
  AudioTrack(
    audioId: 'aud-b',
    r2Key: 'assets/praises/p1/b.mp3',
    nome: 'B',
    numero: '001',
    groupId: 'p1',
    categoria: 'Playback',
    classificacao: 'Coro',
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('close deixa a sessão vazia', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(audioPlayerSessionProvider.notifier).close();

    final state = container.read(audioPlayerSessionProvider);
    expect(state.queue, isEmpty);
    expect(state.playing, isFalse);
    expect(container.read(audioPlayerPositionProvider).position, Duration.zero);
    expect(state.currentTrack, isNull);
  });

  test('restoreQueue preenche a fila e não toca', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(audioPlayerSessionProvider.notifier)
        .restoreQueue(_tracks, startIndex: 1);

    final state = container.read(audioPlayerSessionProvider);
    expect(state.queue, _tracks);
    expect(state.currentIndex, 1);
    expect(state.playing, isFalse);
    expect(
      state.restoredWithoutPlayback,
      isTrue,
      reason: 'a restauração precisa se identificar para "Seguir o áudio"',
    );
  });

  test('sessão nova não nasce marcada como restaurada (A6)', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(audioPlayerSessionProvider).restoredWithoutPlayback,
      isFalse,
      reason: 'sem restauração a primeira faixa da sessão pode seguir o leitor',
    );
  });

  test('ação de reprodução do usuário encerra a marca (A6)', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(audioPlayerSessionProvider.notifier);
    await notifier.restoreQueue(_tracks);
    expect(
      container.read(audioPlayerSessionProvider).restoredWithoutPlayback,
      isTrue,
    );

    // `skipToNext` não completa sem o plugin nativo; a marca cai antes do
    // primeiro `await`, que é o ponto do teste.
    unawaited(notifier.skipToNext());

    expect(
      container.read(audioPlayerSessionProvider).restoredWithoutPlayback,
      isFalse,
    );
  });

  group('shouldShowCarouselAudioFace', () {
    test(
      'após close (fila vazia + face PDF) não mostra áudio só por playlist',
      () {
        expect(
          shouldShowCarouselAudioFace(
            face: PlaylistMediaFace.pdf,
            hasPdf: true,
            hasSessionQueue: false,
            hasAudioPlaylist: true,
          ),
          isFalse,
        );
      },
    );

    test('sem PDF e sem sessão, playlist com áudio não reabre sozinha', () {
      expect(
        shouldShowCarouselAudioFace(
          face: PlaylistMediaFace.pdf,
          hasPdf: false,
          hasSessionQueue: false,
          hasAudioPlaylist: true,
        ),
        isFalse,
      );
    });

    test('face áudio explícita reabre a barra', () {
      expect(
        shouldShowCarouselAudioFace(
          face: PlaylistMediaFace.audio,
          hasPdf: true,
          hasSessionQueue: false,
          hasAudioPlaylist: true,
        ),
        isTrue,
      );
    });

    test('face áudio sem sessão nem audioIds fica na face PDF', () {
      expect(
        shouldShowCarouselAudioFace(
          face: PlaylistMediaFace.audio,
          hasPdf: true,
          hasSessionQueue: false,
          hasAudioPlaylist: false,
        ),
        isFalse,
      );
    });

    test('sessão ativa sem PDF mostra face áudio', () {
      expect(
        shouldShowCarouselAudioFace(
          face: PlaylistMediaFace.pdf,
          hasPdf: false,
          hasSessionQueue: true,
          hasAudioPlaylist: false,
        ),
        isTrue,
      );
    });
  });
}
