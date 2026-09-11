import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Posição/duração da faixa tocando — separado de [AudioPlayerSessionState]
/// (`audio_player_session_provider.dart`) para o `positionStream` do
/// `just_audio` (~5 Hz) não trocar a identidade do estado da sessão a cada
/// tick, o que forçava um rebuild de tudo que observava a sessão inteira
/// (barra do shell, presente em toda rota) (A7).
final class AudioPlayerPosition {
  const AudioPlayerPosition({
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final Duration position;
  final Duration duration;

  /// 0..1; 0 quando [duration] é zero (evita divisão por zero) e nunca passa
  /// de 1 mesmo com [position] além de [duration].
  double get progress {
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0) return 0;
    final ratio = position.inMilliseconds / totalMs;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }
}

/// Só [AudioPlayerSessionNotifier] (`audio_player_session_provider.dart`)
/// chama [update]/[reset] — a partir dos listeners de `positionStream` e
/// `durationStream` do player. Os demais widgets só observam.
class AudioPlayerPositionNotifier extends Notifier<AudioPlayerPosition> {
  @override
  AudioPlayerPosition build() => const AudioPlayerPosition();

  void update({Duration? position, Duration? duration}) {
    state = AudioPlayerPosition(
      position: position ?? state.position,
      duration: duration ?? state.duration,
    );
  }

  void reset() {
    state = const AudioPlayerPosition();
  }
}

final audioPlayerPositionProvider =
    NotifierProvider<AudioPlayerPositionNotifier, AudioPlayerPosition>(
      AudioPlayerPositionNotifier.new,
    );
