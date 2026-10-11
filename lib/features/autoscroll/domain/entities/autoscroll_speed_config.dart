/// Constantes centrais de velocidade do autoscroll para todos os leitores
/// (cifras, gestos e letra).
///
/// Faixa de 1 a 15, com padrão exatamente no meio (8) e 14 divisões discretas
/// magnéticas no Slider.
abstract final class AutoscrollSpeedConfig {
  static const int min = 1;
  static const int max = 15;
  static const int initial = 8;
  static const int divisions = max - min; // 14 passos discretos

  static int clamp(int speed) => speed.clamp(min, max);
}
