import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../autoscroll/domain/entities/autoscroll_speed_config.dart';

const int kLyricsAutoscrollMinSpeed = AutoscrollSpeedConfig.min;
const int kLyricsAutoscrollMaxSpeed = AutoscrollSpeedConfig.max;
const int kLyricsAutoscrollDefaultSpeed = AutoscrollSpeedConfig.initial;
const double kLyricsAutoscrollPxPerSecondPerSpeed = 12;

class LyricsAutoscrollState {
  const LyricsAutoscrollState({required this.running, required this.speed});

  final bool running;
  final int speed;

  LyricsAutoscrollState copyWith({bool? running, int? speed}) {
    return LyricsAutoscrollState(
      running: running ?? this.running,
      speed: speed ?? this.speed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricsAutoscrollState &&
          other.running == running &&
          other.speed == speed);

  @override
  int get hashCode => Object.hash(running, speed);
}

class LyricsAutoscrollNotifier extends Notifier<LyricsAutoscrollState> {
  @override
  LyricsAutoscrollState build() => const LyricsAutoscrollState(
        running: false,
        speed: kLyricsAutoscrollDefaultSpeed,
      );

  void toggle() => state = state.copyWith(running: !state.running);

  void setSpeed(int speed) {
    final clamped = speed.clamp(
      kLyricsAutoscrollMinSpeed,
      kLyricsAutoscrollMaxSpeed,
    );
    if (clamped == state.speed) return;
    state = state.copyWith(speed: clamped);
  }

  void stop() {
    if (!state.running) return;
    state = state.copyWith(running: false);
  }
}

final lyricsAutoscrollProvider = NotifierProvider.autoDispose<
    LyricsAutoscrollNotifier, LyricsAutoscrollState>(
  LyricsAutoscrollNotifier.new,
);
