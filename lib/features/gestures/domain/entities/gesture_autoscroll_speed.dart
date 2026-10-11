import '../../../autoscroll/domain/entities/autoscroll_speed_config.dart';

/// Faixa da velocidade do autoscroll do leitor de gestos.
///
/// Níveis inteiros de 1 a 15, com padrão no meio (8).
abstract final class GestureAutoscrollSpeed {
  static const int min = AutoscrollSpeedConfig.min;
  static const int max = AutoscrollSpeedConfig.max;
  static const int initial = AutoscrollSpeedConfig.initial;

  /// Pixels por segundo por nível — o motor multiplica pelo nível.
  static const double pxPerSecondPerLevel = 10;

  static int clamp(int speed) => speed.clamp(min, max);
}
