import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/gesture_reader_preferences_datasource.dart';
import '../../domain/entities/gesture_autoscroll_speed.dart';

/// Estado do autoscroll do leitor de gestos.
class GestureAutoscrollState {
  const GestureAutoscrollState({required this.running, required this.speed});

  final bool running;

  /// Entre [GestureAutoscrollSpeed.min] e [GestureAutoscrollSpeed.max].
  final int speed;

  GestureAutoscrollState copyWith({bool? running, int? speed}) =>
      GestureAutoscrollState(
        running: running ?? this.running,
        speed: speed ?? this.speed,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GestureAutoscrollState &&
          other.running == running &&
          other.speed == speed);

  @override
  int get hashCode => Object.hash(running, speed);
}

/// Liga/desliga e regula a velocidade do autoscroll dos gestos.
///
/// Como `ChordAutoscrollNotifier`: o motor (`Ticker`) mora no `State` da
/// tela; aqui fica só a intenção. `autoDispose` para o "ligado" não vazar
/// para a próxima abertura do leitor. A **velocidade**, ao contrário da
/// cifra, persiste: é a preferência da regente, não um ajuste de momento.
class GestureAutoscrollNotifier extends Notifier<GestureAutoscrollState> {
  @override
  GestureAutoscrollState build() => GestureAutoscrollState(
    running: false,
    speed: _datasource.getAutoscrollSpeed(),
  );

  GestureReaderPreferencesDatasource get _datasource =>
      GestureReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void toggle() => state = state.copyWith(running: !state.running);

  void setSpeed(int speed) {
    final clamped = GestureAutoscrollSpeed.clamp(speed);
    if (clamped == state.speed) return;
    state = state.copyWith(speed: clamped);
    unawaited(_datasource.saveAutoscrollSpeed(clamped));
  }

  /// Desliga sem notificar quando já estava parado.
  void stop() {
    if (!state.running) return;
    state = state.copyWith(running: false);
  }
}

final gestureAutoscrollProvider =
    NotifierProvider.autoDispose<GestureAutoscrollNotifier, GestureAutoscrollState>(
      GestureAutoscrollNotifier.new,
    );
