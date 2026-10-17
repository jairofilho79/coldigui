import 'dart:async';
import 'package:flutter/services.dart';

/// Utilitário centralizado para feedback tátil (haptic feedback) seguro.
///
/// Todas as invocações são protegidas contra falhas em plataformas onde
/// a vibração não é suportada ou permitida (ex.: desktop web, navegadores restritos,
/// emuladores ou testes automatizados).
abstract final class AppHaptics {
  /// Controla se o feedback háptico está ativo globalmente (útil para testes ou preferências).
  static bool enabled = true;

  /// Vibração sutil para seleção de itens, toques em passos de tutorial ou navegação.
  static Future<void> selectionClick() async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Impacto tátil leve para botões de ação e viradas de página.
  static Future<void> lightImpact() async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Impacto tátil médio para conclusão de etapas, salvar preferências ou confirmações.
  static Future<void> mediumImpact() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}
