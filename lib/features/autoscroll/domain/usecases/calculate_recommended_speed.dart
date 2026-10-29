import '../entities/autoscroll_speed_config.dart';

/// Calcula a velocidade de autoscroll recomendada para um louvor,
/// ponderando a velocidade previamente ajustada pelo tamanho atual da fonte.
///
/// Física do leitor:
/// - Um corpo de letra maior gera mais linhas e maior altura vertical total.
/// - Para percorrer o louvor no mesmo tempo musical, a rolagem precisa ser
///   proporcionalmente mais rápida quando a fonte aumenta, e mais lenta quando diminui.
/// - A fórmula calcula: `round(baseSpeed * (currentFontSize / baseFontSize))`
///   grampeada na faixa `[AutoscrollSpeedConfig.min, AutoscrollSpeedConfig.max]`.
int calculateRecommendedSpeed({
  required int baseSpeed,
  required double baseFontSize,
  required double currentFontSize,
}) {
  if (baseFontSize <= 0 || currentFontSize <= 0) {
    return AutoscrollSpeedConfig.clamp(baseSpeed);
  }
  final ratio = currentFontSize / baseFontSize;
  final scaled = (baseSpeed * ratio).round();
  return AutoscrollSpeedConfig.clamp(scaled);
}
