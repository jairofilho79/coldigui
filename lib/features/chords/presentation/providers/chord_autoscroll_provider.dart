import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Velocidade mínima aceita por [ChordAutoscrollNotifier.setSpeed].
const int kChordAutoscrollMinSpeed = 1;

/// Velocidade máxima aceita por [ChordAutoscrollNotifier.setSpeed].
const int kChordAutoscrollMaxSpeed = 5;

/// Velocidade inicial do autoscroll, antes de qualquer ajuste do usuário.
const int kChordAutoscrollDefaultSpeed = 3;

/// Pixels por segundo, por unidade de velocidade — o motor (no `State` da
/// tela) multiplica isso por [ChordAutoscrollState.speed].
const double kChordAutoscrollPxPerSecondPerSpeed = 12;

/// Estado do autoscroll do leitor de cifras (C9).
class ChordAutoscrollState {
  const ChordAutoscrollState({required this.running, required this.speed});

  final bool running;

  /// Entre [kChordAutoscrollMinSpeed] e [kChordAutoscrollMaxSpeed].
  final int speed;

  ChordAutoscrollState copyWith({bool? running, int? speed}) {
    return ChordAutoscrollState(
      running: running ?? this.running,
      speed: speed ?? this.speed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChordAutoscrollState &&
          other.running == running &&
          other.speed == speed);

  @override
  int get hashCode => Object.hash(running, speed);
}

/// Liga/desliga e regula a velocidade do autoscroll da cifra (C9).
///
/// O motor de rolagem em si (o `Ticker`) mora no `State` da tela — este
/// notifier só guarda a intenção do usuário (rodando ou não, em qual
/// velocidade). `autoDispose`: some quando ninguém mais observa, ou seja,
/// quando o leitor de cifras fecha — sem isso o autoscroll de uma sessão
/// vazaria "ligado" para a próxima abertura do leitor.
class ChordAutoscrollNotifier extends Notifier<ChordAutoscrollState> {
  @override
  ChordAutoscrollState build() => const ChordAutoscrollState(
    running: false,
    speed: kChordAutoscrollDefaultSpeed,
  );

  void toggle() => state = state.copyWith(running: !state.running);

  void setSpeed(int speed) {
    final clamped = speed.clamp(
      kChordAutoscrollMinSpeed,
      kChordAutoscrollMaxSpeed,
    );
    if (clamped == state.speed) return;
    state = state.copyWith(speed: clamped);
  }

  /// Desliga sem efeito quando já estava parado — evita notificar ouvintes à
  /// toa (por exemplo, a cada troca de louvor sem autoscroll ativo).
  void stop() {
    if (!state.running) return;
    state = state.copyWith(running: false);
  }
}

final chordAutoscrollProvider =
    NotifierProvider.autoDispose<ChordAutoscrollNotifier, ChordAutoscrollState>(
      ChordAutoscrollNotifier.new,
    );
