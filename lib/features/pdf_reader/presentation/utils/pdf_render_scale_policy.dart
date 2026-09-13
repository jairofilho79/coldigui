import 'dart:math' as math;

/// Política de escala de rasterização da **preview** do leitor (diagnóstico
/// pdfrx 2.6.1, Fase 1.3).
///
/// As partituras do catálogo são scans de ~210 dpi (≈ 2,9× sobre os 72 pt do
/// PDF): acima de ~3× o PDFium só interpola pixels que já existem, gastando
/// CPU e memória sem ganho visual. Isso não tampona o pinch inteiro: no pdfrx
/// 2.6.1, `_paintPages` chama `getPageRenderingScale` uma vez por página com
/// `estimatedScale` fixo em `onePassRenderingScaleThreshold` (3.0) e usa o
/// resultado só para a rasterização de **preview** — na prática
/// `min(3.0, 2×DPR)` (2× em tela 1×, 3× a partir de DPR ≥ 1,5). Os tiles
/// «real size» (parciais, limitados à viewport) que cobrem zoom acima dessa
/// escala continuam renderizando a `zoom × DPR`, limitados só pelo `maxScale`
/// (8×) do [PdfViewerParams] — esta política não os alcança. Sem import
/// `pdfrx` (ADR-002).
abstract final class PdfRenderScalePolicy {
  /// Teto absoluto (unidades do documento → pixels físicos).
  static const double ceiling = 3.0;

  /// Teto relativo ao DPR — numa tela 1× (desktop) 2× já cobre o zoom usual e
  /// evita bitmaps que a viewport não mostra.
  static const int dprMultiplier = 2;

  /// `min(estimatedScale, dprMultiplier × devicePixelRatio, ceiling)`.
  static double resolve({
    required double estimatedScale,
    required double devicePixelRatio,
  }) {
    final dprCeiling = dprMultiplier * devicePixelRatio;
    return math.min(estimatedScale, math.min(dprCeiling, ceiling));
  }
}
