/// Faixa e passo do corpo da letra no leitor de gestos (spec §4).
///
/// Base 18 porque a letra é lida a um braço de distância, com o aparelho na
/// mão; abaixo de 14 o gatilho some, acima de 28 a figura (que escala junto)
/// engole a largura do celular.
abstract final class GestureReaderFontSize {
  static const double min = 14;
  static const double max = 28;
  static const double step = 2;
  static const double initial = 18;

  static double clamp(double size) => size.clamp(min, max);

  static double increase(double size) => clamp(size + step);

  static double decrease(double size) => clamp(size - step);

  static bool canIncrease(double size) => size < max;

  static bool canDecrease(double size) => size > min;
}
