/// Política do «salto curto» na navegação programática para páginas
/// distantes (long-press no indicador, «Ir para a página», restauração da
/// última página, `Home`/`End`).
///
/// O `goToPage` animado do pdfrx interpola um único `Matrix4Tween` da
/// posição atual até o destino: toda página que atravessa a tela entra na
/// fila de renderização (rasterizada para ninguém ver) e a página de
/// destino, já fora do cache, fica atrás dela — solavancos e tela branca
/// antes de o destino aparecer. Com destino a mais de uma página, o viewer
/// salta sem animação para a vizinha do destino **do lado de onde se vem**
/// e anima só o último trecho ([finalLegDuration]). Virada para a página
/// vizinha (borda, deslize, setas) não passa pelo salto.
///
/// Pura (sem `pdfrx`, ADR-002): o handle aplica o resultado no controller.
abstract final class PdfPageJumpPolicy {
  /// Duração da animação do último trecho, da vizinha até o destino —
  /// curta o bastante para não parecer atraso e longa o bastante para
  /// mostrar de que lado a página chegou.
  static const finalLegDuration = Duration(milliseconds: 350);

  /// Página onde o salto instantâneo pousa antes de animar até [to], ou
  /// `null` quando a navegação anima direto (distância ≤ 1, ou documento
  /// com menos de duas páginas).
  ///
  /// [from] e [to] fora de `1..pageCount` contam como a página da borda —
  /// o `goToPage` do pdfrx clampa o destino do mesmo jeito. Subindo (da 16
  /// para a 1) pousa em `to + 1`; descendo (da 1 para a 16), em `to - 1`.
  static int? landingPage({
    required int from,
    required int to,
    required int pageCount,
  }) {
    if (pageCount < 2) return null;
    final origin = from.clamp(1, pageCount);
    final target = to.clamp(1, pageCount);
    if ((target - origin).abs() <= 1) return null;
    return target > origin ? target - 1 : target + 1;
  }
}
