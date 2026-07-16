import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_chips.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('close deixa a sessão vazia', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(audioPlayerSessionProvider.notifier).close();

    final state = container.read(audioPlayerSessionProvider);
    expect(state.queue, isEmpty);
    expect(state.playing, isFalse);
    expect(state.position, Duration.zero);
    expect(state.currentTrack, isNull);
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
