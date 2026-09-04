// test/widget/features/audio_player/play_audio_in_session_storage_test.dart
//
// A1: tocar do sheet com Isar indisponível toca a faixa e **não** tenta
// escrever na lista ativa (mesma porteira de `addMaterialToActivePlaylist`).
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _track = AudioTrack(
  audioId: 'audio1',
  r2Key: 'audio-key',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'g1',
  categoria: 'Playback',
  classificacao: 'Básico',
  author: 'CIAS',
  source: LouvorDataSource.coldigom,
);

class _FakeSession extends AudioPlayerSessionNotifier {
  final List<List<AudioTrack>> played = [];

  @override
  AudioPlayerSessionState build() => const AudioPlayerSessionState();

  @override
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    played.add(tracks);
  }
}

/// Só registra; a versão real lança `StorageUnavailableException` sem Isar.
class _RecordingPlaylists extends PlaylistsNotifier {
  final List<String> addedAudioIds = [];

  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<bool> addAudioToActivePlaylist(String audioId) async {
    addedAudioIds.add(audioId);
    return true;
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpAndPlay(
    WidgetTester tester, {
    required bool isarAvailable,
    required _FakeSession session,
    required _RecordingPlaylists playlists,
  }) async {
    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isarAvailableProvider.overrideWithValue(isarAvailable),
          audioPlayerSessionProvider.overrideWith(() => session),
          playlistsProvider.overrideWith(() => playlists),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await playAudioInSession(ref: capturedRef, track: _track);
    await tester.pump();
  }

  testWidgets('sem Isar, tocar do sheet toca e não escreve na lista', (
    tester,
  ) async {
    final session = _FakeSession();
    final playlists = _RecordingPlaylists();

    await pumpAndPlay(
      tester,
      isarAvailable: false,
      session: session,
      playlists: playlists,
    );

    expect(session.played, hasLength(1));
    expect(session.played.single.single.audioId, 'audio1');
    expect(playlists.addedAudioIds, isEmpty);
  });

  testWidgets('com Isar, tocar do sheet continua entrando na lista', (
    tester,
  ) async {
    final session = _FakeSession();
    final playlists = _RecordingPlaylists();

    await pumpAndPlay(
      tester,
      isarAvailable: true,
      session: session,
      playlists: playlists,
    );

    expect(session.played, hasLength(1));
    expect(playlists.addedAudioIds, ['audio1']);
  });
}
