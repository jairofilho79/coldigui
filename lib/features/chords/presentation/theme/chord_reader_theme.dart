import 'package:flutter/material.dart';

import '../../../../core/theme/color_extensions.dart';

/// Cores de uma variante do leitor de cifras.
class ChordReaderPalette {
  const ChordReaderPalette({
    required this.background,
    required this.lyric,
    required this.chord,
    required this.bar,
    required this.comment,
  });

  final Color background;
  final Color lyric;
  final Color chord;

  /// Vermelho da barra que marca a sílaba do acorde.
  final Color bar;

  final Color comment;
}

/// Claro/escuro **local ao leitor de cifras**.
///
/// O app tem paleta litúrgica única ([AppColors]) e não tem dark mode global.
/// Este toggle não toca em [ThemeData] — vale só dentro do leitor.
enum ChordReaderMode {
  light,
  dark;

  /// Cores da variante. O vermelho da barra difere entre as duas: o mesmo tom
  /// sobre creme e sobre carvão não tem o mesmo contraste.
  ChordReaderPalette get palette => switch (this) {
    ChordReaderMode.light => const ChordReaderPalette(
      background: AppColors.card,
      lyric: AppColors.textDark,
      chord: AppColors.title,
      bar: Color(0xFFC62828),
      comment: Color(0xFF6B6B6B),
    ),
    ChordReaderMode.dark => const ChordReaderPalette(
      background: AppColors.pdfArea,
      lyric: AppColors.textLight,
      chord: AppColors.goldLight,
      bar: Color(0xFFFF5252),
      comment: Color(0xFFB0B0B0),
    ),
  };

  ChordReaderMode toggle() =>
      this == ChordReaderMode.light ? ChordReaderMode.dark : ChordReaderMode.light;

  /// Serializa para [StorageKeys.chordReaderMode].
  String toStorageString() => name;

  /// Restaura; `null` se inválido.
  static ChordReaderMode? fromStorageString(String? value) => switch (value) {
    'light' => ChordReaderMode.light,
    'dark' => ChordReaderMode.dark,
    _ => null,
  };
}
