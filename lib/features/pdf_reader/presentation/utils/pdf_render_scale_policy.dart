import 'dart:math' as math;

/// Política de escala de rasterização da **preview** do leitor (diagnóstico
/// pdfrx 2.6.1, Fase 1.3; escala pela tela, 2026-09-25).
///
/// As partituras do catálogo são scans de ~210 dpi (≈ 2,9× sobre os 72 pt do
/// PDF): acima de ~3× o PDFium só interpola pixels que já existem, gastando
/// CPU e memória sem ganho visual. Isso não tampona o pinch inteiro: no pdfrx
/// 2.6.1, `_paintPages` chama `getPageRenderingScale` uma vez por página com
/// `estimatedScale` fixo em `onePassRenderingScaleThreshold` (3.0) e usa o
/// resultado só para a rasterização de **preview**. Os tiles «real size»
/// (parciais, limitados à viewport) cobrem o zoom acima da escala da preview
/// e renderizam a `zoom × DPR`, limitados só pelo `maxScale` (8×) do
/// [PdfViewerParams] — esta política não os alcança. Sem import `pdfrx`
/// (ADR-002).
///
/// Na web cada preview vira `ui.Image` por um caminho caro na thread
/// principal (BMP montado pixel a pixel + cópia byte a byte para o JS —
/// tarefas de 120–240 ms por página A4 no Chrome), proporcional aos pixels.
/// Por isso [resolveForFit] rasteriza no tamanho que a tela mostra no zoom
/// de repouso, não no teto: A4 num iPhone sai a 2,17× («ajustar largura») ou
/// 2,44× («página inteira») — 48% ou 34% menos pixels que 3×.
abstract final class PdfRenderScalePolicy {
  /// Teto absoluto (unidades do documento → pixels físicos).
  static const double ceiling = 3.0;

  /// Folga sobre o [ceiling] em que a preview ainda segue a tela. Um scan
  /// ~A5 no iPhone é exibido a 3,03×: preso em 3,0, o pdfrx rasterizava a
  /// página duas vezes a cada parada do scroll (preview + tiles «real size»
  /// a 3,03). Acima da folga (iPad Pro com A4, 3,4×) volta ao teto e os
  /// tiles cobrem a diferença, como antes.
  static const double ceilingTolerance = 1.1;

  /// Piso — viewport minúsculo (ou ainda sem layout) não gera bitmap inútil.
  static const double floor = 1.0;

  /// Teto relativo ao DPR — numa tela 1× (desktop) 2× já cobre o zoom usual e
  /// evita bitmaps que a viewport não mostra.
  static const int dprMultiplier = 2;

  /// `min(estimatedScale, dprMultiplier × devicePixelRatio, ceiling)` — usado
  /// enquanto o viewer ainda não tem layout (sem viewport não há como medir
  /// o zoom de repouso).
  static double resolve({
    required double estimatedScale,
    required double devicePixelRatio,
  }) {
    final dprCeiling = dprMultiplier * devicePixelRatio;
    return math.min(estimatedScale, math.min(dprCeiling, ceiling));
  }

  /// Escala da preview = pixels físicos por pt que a página ocupa no zoom de
  /// repouso, arredondada para cima em centésimos (fica ≥ a escala exibida, e
  /// o pdfrx não pede tiles «real size» a cada parada do scroll).
  ///
  /// O zoom de repouso é o maior entre [coverScale] (zoom inicial do pdfrx:
  /// documento + margens na largura), «ajustar largura»
  /// (`(viewWidth − 2 × pageMargin) / pageLayoutWidth`, como
  /// `calcMatrixFitWidthForPage`) e «página inteira»
  /// (`(viewHeight − 2 × pageMargin) / pageLayoutHeight`, como
  /// `calcMatrixFitHeightForPage` — o padrão do app; num celular em pé deixa
  /// a A4 mais larga que a tela). Cobre os dois modos sem ler o estado da
  /// tela e é constante durante o scroll — muda só com a viewport (tela cheia,
  /// rotação), o que evita re-rasterizar a cada frame. No pinch acima do
  /// repouso os tiles «real size» assumem.
  ///
  /// `pageLayout*` é o tamanho da página no layout (unidades de documento);
  /// `pagePoint*`, no PDF (pt). Iguais no layout padrão; o spread pode diferir
  /// — a razão entra como no `pageScale` do pdfrx (maior dos dois eixos).
  static double resolveForFit({
    required double devicePixelRatio,
    required double viewWidth,
    required double viewHeight,
    required double pageMargin,
    required double coverScale,
    required double pageLayoutWidth,
    required double pageLayoutHeight,
    required double pagePointWidth,
    required double pagePointHeight,
  }) {
    if (!(pageLayoutWidth > 0) ||
        !(pageLayoutHeight > 0) ||
        !(pagePointWidth > 0) ||
        !(pagePointHeight > 0)) {
      return ceiling;
    }
    final fitWidthZoom = (viewWidth - pageMargin * 2) / pageLayoutWidth;
    final fitHeightZoom = (viewHeight - pageMargin * 2) / pageLayoutHeight;
    final restZoom = math.max(
      coverScale,
      math.max(fitWidthZoom, fitHeightZoom),
    );
    final layoutRatio = math.max(
      pageLayoutWidth / pagePointWidth,
      pageLayoutHeight / pagePointHeight,
    );
    final displayed = restZoom * devicePixelRatio * layoutRatio;
    if (!displayed.isFinite) return ceiling;
    if (displayed > ceiling * ceilingTolerance) return ceiling;
    final rounded = (displayed * 100).ceilToDouble() / 100;
    return math.max(floor, rounded);
  }
}
