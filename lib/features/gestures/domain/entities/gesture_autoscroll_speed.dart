/// Faixa da velocidade do autoscroll do leitor de gestos.
///
/// Níveis inteiros, como na cifra, mas mais lentos por nível: a linha de
/// gesto (figura de 96 dp) é mais alta que a de cifra, e a regente faz os
/// gestos com as mãos enquanto lê — 10 px/s por nível dá 10–50 px/s.
abstract final class GestureAutoscrollSpeed {
  static const int min = 1;
  static const int max = 5;
  static const int initial = 3;

  /// Pixels por segundo por nível — o motor multiplica pelo nível.
  static const double pxPerSecondPerLevel = 10;

  static int clamp(int speed) => speed.clamp(min, max);
}
