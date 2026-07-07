import 'package:flutter/material.dart';

/// Tokens do tema Coletânea Digital (§6 MAPEAMENTO).
///
/// Cores, sombras (`shadowMd`, `shadowLg`) e `goldGlow` para animações
/// do design system litúrgico (bordas douradas, cards, glow na busca).
abstract final class AppColors {
  static const Color background = Color(0xFF4B2D2B);
  static const Color card = Color(0xFFFFF8E1);
  static const Color title = Color(0xFF6A2F2F);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF4D03F);
  static const Color placeholder = Color(0xFFF0E68C);
  static const Color btnBackground = Color(0xFF6A3B39);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2C3E50);
  static const Color pdfArea = Color(0xFF2A2A2A);
  static const Color chipColdigom = Color(0xFF0F0E13);
  static const Color offlineReady = Color(0xFF28A745);
  static const Color offlineMissing = Color(0xFFDC3545);

  /// Elevação padrão (§6.2).
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4)),
  ];

  /// Hover / destaque (§6.2).
  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x33000000), blurRadius: 15, offset: Offset(0, 10)),
  ];

  /// Brilho dourado para glow animado.
  static const Color goldGlow = Color(0x66FFDC64);
}
