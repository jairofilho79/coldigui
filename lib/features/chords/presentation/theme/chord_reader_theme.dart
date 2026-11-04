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
    required this.stripe,
    Color? chorusBorder,
    Color? chorusBackground,
    Color? introBorder,
    Color? introBackground,
  })  : chorusBorder = chorusBorder ?? chord,
        chorusBackground = chorusBackground ?? const Color(0x00000000),
        introBorder = introBorder ?? const Color(0x22888888),
        introBackground = introBackground ?? const Color(0x00000000);

  final Color background;
  final Color lyric;
  final Color chord;

  /// Vermelho da barra que marca a sílaba do acorde.
  final Color bar;

  final Color comment;

  /// Faixa de fundo alternada nas linhas de letra (transparente no novo design limpo).
  final Color stripe;

  /// Borda de destaque lateral da seção de Coro/Refrão.
  final Color chorusBorder;

  /// Fundo translúcido sutil da seção de Coro/Refrão.
  final Color chorusBackground;

  /// Borda do contêiner de introdução/compassos instrumentais.
  final Color introBorder;

  /// Fundo sutil do contêiner de introdução instrumental.
  final Color introBackground;
}

/// Claro/escuro **local ao leitor de cifras**.
///
/// O app tem paleta litúrgica única ([AppColors]) e não tem dark mode global.
/// Este toggle não toca em [ThemeData] — vale só dentro do leitor.
enum ChordReaderMode {
  light,
  dark;

  /// Cores da variante com identidade litúrgica PLPCG:
  /// - Modo Claro: papel marfim litúrgico aquecido (#FAF8F5) e acordes carmim nobre (#B71C1C).
  /// - Modo Escuro: palco carvão imersivo (#191414) e ouro nobre litúrgico (#E5C068).
  ChordReaderPalette get palette => switch (this) {
    ChordReaderMode.light => const ChordReaderPalette(
      background: Color(0xFFFAF8F5),
      lyric: AppColors.textDark,
      chord: Color(0xFFB71C1C),
      bar: Color(0xFFC62828),
      comment: Color(0xFF6B6B6B),
      stripe: Colors.transparent,
      chorusBorder: Color(0xFFB71C1C),
      chorusBackground: Color(0xFFFBF5EA),
      introBorder: Color(0x2EB71C1C),
      introBackground: Color(0x08B71C1C),
    ),
    ChordReaderMode.dark => const ChordReaderPalette(
      background: Color(0xFF191414),
      lyric: AppColors.textLight,
      chord: Color(0xFFE5C068),
      bar: Color(0xFFFF5252),
      comment: Color(0xFFB0B0B0),
      stripe: Colors.transparent,
      chorusBorder: Color(0xFFE5C068),
      chorusBackground: Color(0x0DE5C068),
      introBorder: Color(0x33E5C068),
      introBackground: Color(0x0AE5C068),
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
