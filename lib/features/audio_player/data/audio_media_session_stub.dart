import '../domain/entities/audio_track.dart';

/// Callbacks de transporte vindos do OS (lock screen / fones).
typedef AudioMediaSessionCallbacks = ({
  Future<void> Function() onPlay,
  Future<void> Function() onPause,
  Future<void> Function() onPrevious,
  Future<void> Function() onNext,
  Future<void> Function(Duration position) onSeek,
});

/// No-op fora da web.
class AudioMediaSessionController {
  void attach({required AudioMediaSessionCallbacks callbacks}) {}

  void detach() {}

  void updateTrack(AudioTrack? track) {}

  void updatePlaybackState({required bool playing}) {}

  void updatePosition({
    required Duration position,
    required Duration duration,
  }) {}
}

AudioMediaSessionController createAudioMediaSessionController() {
  return AudioMediaSessionController();
}
