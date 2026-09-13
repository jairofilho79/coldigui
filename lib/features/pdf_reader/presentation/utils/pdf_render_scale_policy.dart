import 'dart:math' as math;

/// Política de escala de rasterização do leitor (diagnóstico pdfrx, Fase 1.3).
///
/// As partituras do catálogo são scans de ~210 dpi (≈ 2,9× sobre os 72 pt do
/// PDF): acima de ~3× o PDFium só interpola pixels que já existem, gastando
/// CPU e memória sem ganho visual. Antes o nativo rasterizava sem teto (até
/// 8× no pinch) e a web tinha só o teto por DPR; agora a mesma regra vale
/// para todas as plataformas. Sem import `pdfrx` (ADR-002).
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
