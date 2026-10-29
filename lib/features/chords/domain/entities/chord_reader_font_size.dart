/// Faixa e passo do corpo da letra no leitor de cifras.
///
/// Abaixo de 12 a cifra fica ilegível em celular; acima de 28 quase toda linha
/// com acorde quebra, e a quebra acontece entre células — o que empilha
/// sílabas soltas e desmancha a leitura.
abstract final class ChordReaderFontSize {
  static const double min = 12;
  static const double max = 28;
  static const double step = 2;
  static const double initial = 16;

  /// Grampeia [size] na faixa suportada.
  static double clamp(double size) => size.clamp(min, max);

  /// Próximo passo acima, ou o mesmo valor quando já está no teto.
  static double increase(double size) => clamp(size + step);

  /// Próximo passo abaixo, ou o mesmo valor quando já está no piso.
  static double decrease(double size) => clamp(size - step);

  static bool canIncrease(double size) => size < max;

  static bool canDecrease(double size) => size > min;
}
