import 'package:flutter/material.dart';

import '../../../../core/theme/color_extensions.dart';
import 'gesture_reader_palette.dart';

/// Claro/escuro **local ao leitor de gestos**, como `ChordReaderMode` na
/// cifra: o app não tem dark mode global e este toggle não toca em
/// `ThemeData`. Independente do tema da cifra — quem rege gestos não
/// necessariamente abre cifra.
enum GestureReaderMode {
  light,
  dark;

  GestureReaderPalette get palette => switch (this) {
    GestureReaderMode.light => const GestureReaderPalette(
      paper: AppColors.card,
      stripe: Color(0x0A6A2F2F),
      trigger: Color(0xFFC62828),
      lyric: AppColors.textDark,
      blue: Color(0xFF1E63C8),
      orange: Color(0xFFE08A1E),
      wine: AppColors.title,
      instructionBg: Color(0xFFF3EDDC),
      instructionText: Color(0xFF4A4036),
      instructionBorder: Color(0xFFD9CFB8),
      sectionLabel: Color(0xFF8A7F70),
      placeholderBg: Color(0xFFFFF7E6),
      placeholderBorder: Color(0xFFE0B45C),
      figureBg: Color(0xFFFFFFFF),
      figureBorder: Color(0x1A000000),
      // Vinho, não ouro: ouro sobre creme não tem contraste (a cifra faz igual).
      toolbarIcon: AppColors.title,
      divider: Color(0x666A2F2F),
    ),
    GestureReaderMode.dark => const GestureReaderPalette(
      paper: AppColors.pdfArea,
      // Alfa maior no escuro: a mesma faixa que se lê sobre creme some sobre carvão.
      stripe: Color(0x12FFFFFF),
      trigger: Color(0xFFFF5252),
      lyric: AppColors.textLight,
      blue: Color(0xFF7FA9F0),
      orange: Color(0xFFF0B35A),
      wine: AppColors.goldLight,
      instructionBg: Color(0xFF3A3A3A),
      instructionText: Color(0xFFD0D0D0),
      instructionBorder: Color(0xFF555555),
      sectionLabel: Color(0xFF9E9E9E),
      placeholderBg: Color(0xFF3D3420),
      placeholderBorder: Color(0xFFB8933E),
      figureBg: Color(0xFFFFFFFF),
      figureBorder: Color(0x33FFFFFF),
      toolbarIcon: AppColors.goldLight,
      divider: Color(0x66FFFFFF),
    ),
  };

  GestureReaderMode toggle() =>
      this == GestureReaderMode.light ? GestureReaderMode.dark : GestureReaderMode.light;

  /// Serializa para `StorageKeys.gestureReaderMode`.
  String toStorageString() => name;

  /// Restaura; `null` se inválido.
  static GestureReaderMode? fromStorageString(String? value) => switch (value) {
    'light' => GestureReaderMode.light,
    'dark' => GestureReaderMode.dark,
    _ => null,
  };
}
