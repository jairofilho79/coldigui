import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../playlists/presentation/providers/playlist_session_prefs.dart';
import '../../data/audio_media_session.dart';
import '../../data/audio_player_web_providers.dart';
import '../../data/audio_web_unlock.dart';
import '../../data/web_audio_source_resolver.dart';
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
    this.restoredWithoutPlayback = false,
  });

  final List<AudioTrack> queue;
  final int currentIndex;
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool buffering;
  final String? errorMessage;

  /// A fila veio de [AudioPlayerSessionNotifier.restoreQueue] e o usuário ainda
  /// não comandou nenhuma reprodução.
  ///
  /// Sinal explícito de "restauração de sessão" para "Seguir o áudio": antes,
  /// a ausência de faixa anterior servia de proxy e engolia a **primeira**
  /// faixa de uma sessão nova (A6).
  final bool restoredWithoutPlayback;

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
    bool? restoredWithoutPlayback,
  }) {
    return AudioPlayerSessionState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffering: buffering ?? this.buffering,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      restoredWithoutPlayback:
          restoredWithoutPlayback ?? this.restoredWithoutPlayback,
    );
  }
}

/// Índice da sessão enquanto o player troca de fonte.
///
/// `setUrl` / playlist nova dispara [currentIndexStream] em 0 — no iPad isso
/// pintava sempre o primeiro material (ex.: MIDI Geral).
int resolveSessionQueueIndex({
  required int pendingIndex,
  required int? playerIndex,
  required bool applyingSources,
}) {
  if (applyingSources || playerIndex == null) return pendingIndex;
  return playerIndex;
}

/// Sessão única de áudio — fonte de verdade para page e playlist face.
class AudioPlayerSessionNotifier extends Notifier<AudioPlayerSessionState> {
  AudioPlayer? _player;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  AudioMediaSessionController? _mediaSession;
  WebAudioSourceResolver? _sourceResolver;
  bool _mediaSessionAttached = false;
  bool _applyingSources = false;

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
        _mediaSession?.updatePlaybackState(playing: playerState.playing);
      }),
      player.positionStream.listen((position) {
        state = state.copyWith(position: position);
        _mediaSession?.updatePosition(
          position: position,
          duration: state.duration,
        );
      }),
      player.durationStream.listen((duration) {
        if (duration != null) {
          state = state.copyWith(duration: duration);
          _mediaSession?.updatePosition(
            position: state.position,
            duration: duration,
          );
        }
      }),
      player.currentIndexStream.listen((index) {
        if (index == null) return;
        final next = resolveSessionQueueIndex(
          pendingIndex: state.currentIndex,
          playerIndex: index,
          applyingSources: _applyingSources,
        );
        state = state.copyWith(currentIndex: next);
        _mediaSession?.updateTrack(state.currentTrack);
        _persistFocusedAudioId(state.currentTrack?.audioId);
      }),
    ]);
    return player;
  }

  @override
  AudioPlayerSessionState build() {
    if (kIsWeb) {
      _sourceResolver = ref.read(webAudioSourceResolverProvider);
      _mediaSession = ref.read(audioMediaSessionControllerProvider);
    }

    ref.onDispose(() {
      for (final sub in _subscriptions) {
        unawaited(sub.cancel());
      }
      _subscriptions.clear();
      _sourceResolver?.revokeAll();
      _mediaSession?.detach();
      unawaited(_player?.dispose());
      _player = null;
    });
    return const AudioPlayerSessionState();
  }

  void _ensureMediaSessionAttached() {
    if (!kIsWeb || _mediaSessionAttached || _mediaSession == null) return;
    _mediaSession!.attach(
      callbacks: (
        onPlay: playPause,
        onPause: playPause,
        onPrevious: skipToPrevious,
        onNext: skipToNext,
        onSeek: seek,
      ),
    );
    _mediaSessionAttached = true;
  }

  Future<Uri> _playbackUriForTrack(AudioTrack track) async {
    // HTTP + CORP + crossOrigin. blob: com anonymous falha no Chrome/Safari.
    return Uri.parse(AudioTrackUrl.fetchUrlForTrack(track));
  }

  void _persistFocusedAudioId(String? audioId) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (audioId == null || audioId.isEmpty) {
      unawaited(prefs.remove(kPlaylistFocusedAudioIdPrefsKey));
    } else {
      unawaited(prefs.setString(kPlaylistFocusedAudioIdPrefsKey, audioId));
    }
  }

  /// Define fila e inicia em [startIndex].
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) {
    return _applyQueue(tracks, startIndex: startIndex, autoplay: true);
  }

  /// Restaura a fila no reload **sem** tocar.
  Future<void> restoreQueue(List<AudioTrack> tracks, {int startIndex = 0}) {
    return _applyQueue(tracks, startIndex: startIndex, autoplay: false);
  }

  Future<void> _applyQueue(
    List<AudioTrack> tracks, {
    required int startIndex,
    required bool autoplay,
  }) async {
    if (tracks.isEmpty) return;
    final safeIndex = startIndex.clamp(0, tracks.length - 1);
    state = state.copyWith(
      queue: List<AudioTrack>.from(tracks),
      currentIndex: safeIndex,
      playing: false,
      position: Duration.zero,
      duration: Duration.zero,
      clearError: true,
      restoredWithoutPlayback: !autoplay,
    );
    _persistFocusedAudioId(tracks[safeIndex].audioId);

    try {
      final player = _ensurePlayer;
      if (kIsWeb && autoplay) {
        await unlockWebAudioIfNeeded(
          player,
          immediateUrl: AudioTrackUrl.fetchUrlForTrack(tracks[safeIndex]),
        );
      }

      _ensureMediaSessionAttached();

      final sources = <AudioSource>[];
      for (final track in tracks) {
        final uri = await _playbackUriForTrack(track);
        sources.add(
          AudioSource.uri(
            uri,
            tag: MediaItem(
              id: track.audioId,
              title: track.categoria.isNotEmpty ? track.categoria : track.nome,
              album: track.nome,
              artist: track.author.isNotEmpty
                  ? track.author
                  : (track.numero.isNotEmpty ? track.numero : 'Coldigom'),
              extras: {'groupId': track.groupId, 'r2Key': track.r2Key},
            ),
          ),
        );
      }

      _applyingSources = true;
      try {
        await player.setAudioSources(
          sources,
          initialIndex: safeIndex,
          preload: autoplay && !kIsWeb,
        );
        state = state.copyWith(currentIndex: safeIndex, playing: false);
        _mediaSession?.updateTrack(tracks[safeIndex]);
        if (autoplay) {
          await player.play();
        }
      } finally {
        _applyingSources = false;
      }
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString(), playing: false);
    }
  }

  Future<void> playTrack(AudioTrack track) => playQueue([track]);

  /// Marca que o usuário comandou a reprodução, encerrando a restauração.
  void _markUserPlaybackIntent() {
    if (!state.restoredWithoutPlayback) return;
    state = state.copyWith(restoredWithoutPlayback: false);
  }

  Future<void> playPause() async {
    final player = _player;
    if (player == null || state.queue.isEmpty) return;
    _markUserPlaybackIntent();
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
    _markUserPlaybackIntent();
    if (state.position > const Duration(seconds: 3) || !state.hasPrevious) {
      await player.seek(Duration.zero);
      return;
    }
    await player.seekToPrevious();
  }

  Future<void> skipToNext() async {
    if (!state.hasNext) return;
    _markUserPlaybackIntent();
    await _player?.seekToNext();
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    _markUserPlaybackIntent();
    await _player?.seek(Duration.zero, index: index);
    await _player?.play();
  }

  Future<void> stop() async {
    await _player?.stop();
    state = state.copyWith(playing: false, position: Duration.zero);
  }

  /// Encerra o player: para e limpa fila/posição (diferente de [stop]).
  Future<void> close() async {
    await _player?.stop();
    _sourceResolver?.revokeAll();
    _mediaSession?.updateTrack(null);
    state = const AudioPlayerSessionState();
    _persistFocusedAudioId(null);
  }
}

final audioPlayerSessionProvider =
    NotifierProvider<AudioPlayerSessionNotifier, AudioPlayerSessionState>(
      AudioPlayerSessionNotifier.new,
    );
