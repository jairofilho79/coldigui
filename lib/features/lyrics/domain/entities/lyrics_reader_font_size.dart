/// Faixa e passo do corpo do texto no leitor de letra.
///
/// Mesma faixa do leitor de gestos: a letra é lida a um braço de distância;
/// abaixo de 14 some, acima de 28 quase toda linha quebra no celular.
abstract final class LyricsReaderFontSize {
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
