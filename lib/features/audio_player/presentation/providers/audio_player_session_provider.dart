import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/audio_track.dart';
import '../../domain/utils/audio_track_url.dart';

/// Estado da sessão global de áudio (página + face de playlist).
class AudioPlayerSessionState {
  const AudioPlayerSessionState({
    this.queue = const [],
    this.currentIndex = 0,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffering = false,
    this.errorMessage,
  });

  final List<AudioTrack> queue;
  final int currentIndex;
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool buffering;
  final String? errorMessage;

  AudioTrack? get currentTrack {
    if (queue.isEmpty) return null;
    if (currentIndex < 0 || currentIndex >= queue.length) return null;
    return queue[currentIndex];
  }

  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex < queue.length - 1;

  AudioPlayerSessionState copyWith({
    List<AudioTrack>? queue,
    int? currentIndex,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool? buffering,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AudioPlayerSessionState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffering: buffering ?? this.buffering,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Sessão única de áudio — fonte de verdade para page e playlist face.
class AudioPlayerSessionNotifier extends Notifier<AudioPlayerSessionState> {
  AudioPlayer? _player;
  final _subscriptions = <StreamSubscription<dynamic>>[];

  AudioPlayer get _ensurePlayer {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _player = player;
    _subscriptions.addAll([
      player.playerStateStream.listen((playerState) {
        state = state.copyWith(
          playing: playerState.playing,
          buffering:
              playerState.processingState == ProcessingState.loading ||
              playerState.processingState == ProcessingState.buffering,
        );
      }),
      player.positionStream.listen((position) {
        state = state.copyWith(position: position);
      }),
      player.durationStream.listen((duration) {
        if (duration != null) {
          state = state.copyWith(duration: duration);
        }
      }),
      player.currentIndexStream.listen((index) {
        if (index != null) {
          state = state.copyWith(currentIndex: index);
        }
      }),
    ]);
    return player;
  }

  @override
  AudioPlayerSessionState build() {
    ref.onDispose(() {
      for (final sub in _subscriptions) {
        unawaited(sub.cancel());
      }
      _subscriptions.clear();
      unawaited(_player?.dispose());
      _player = null;
    });
    return const AudioPlayerSessionState();
  }

  /// Define fila e inicia em [startIndex].
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final safeIndex = startIndex.clamp(0, tracks.length - 1);
    state = state.copyWith(
      queue: List<AudioTrack>.from(tracks),
      currentIndex: safeIndex,
      position: Duration.zero,
      duration: Duration.zero,
      clearError: true,
    );

    try {
      final player = _ensurePlayer;
      final sources = [
        for (final track in tracks)
          AudioSource.uri(
            Uri.parse(AudioTrackUrl.fromTrack(track)),
            tag: MediaItem(
              id: track.audioId,
              title: track.nome,
              album: track.categoria,
              artist: track.author.isNotEmpty
                  ? track.author
                  : (track.numero.isNotEmpty ? track.numero : 'Coldigom'),
              extras: {'groupId': track.groupId, 'r2Key': track.r2Key},
            ),
          ),
      ];
      await player.setAudioSources(sources, initialIndex: safeIndex);
      await player.play();
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString(), playing: false);
    }
  }

  Future<void> playTrack(AudioTrack track) => playQueue([track]);

  Future<void> playPause() async {
    final player = _player;
    if (player == null || state.queue.isEmpty) return;
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player?.seek(position);
  }

  Future<void> skipToPrevious() async {
    final player = _player;
    if (player == null) return;
    if (state.position > const Duration(seconds: 3) || !state.hasPrevious) {
      await player.seek(Duration.zero);
      return;
    }
    await player.seekToPrevious();
  }

  Future<void> skipToNext() async {
    if (!state.hasNext) return;
    await _player?.seekToNext();
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    await _player?.seek(Duration.zero, index: index);
    await _player?.play();
  }

  Future<void> stop() async {
    await _player?.stop();
    state = state.copyWith(playing: false, position: Duration.zero);
  }
}

final audioPlayerSessionProvider =
    NotifierProvider<AudioPlayerSessionNotifier, AudioPlayerSessionState>(
      AudioPlayerSessionNotifier.new,
    );
