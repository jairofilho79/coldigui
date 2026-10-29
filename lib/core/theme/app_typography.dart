import 'package:flutter/material.dart';

import 'color_extensions.dart';

/// Tipografia Coletânea Digital (§6.3 MAPEAMENTO).
abstract final class AppTypography {
  static const String garamondFamily = 'EBGaramond';
  static const String sansFamily = 'OpenSans';

  static const List<Shadow> _goldTextShadow = [
    Shadow(
      color: Color(0x66D4AF37),
      blurRadius: 8,
      offset: Offset(0, 1),
    ),
  ];

  /// Título "PLPCG" no AppBar.
  static const TextStyle displayPlcpg = TextStyle(
    fontFamily: garamondFamily,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    fontSize: 28,
    letterSpacing: 1.2,
    color: AppColors.placeholder,
    shadows: _goldTextShadow,
  );

  /// Labels de containers, títulos de card.
  static const TextStyle headline = TextStyle(
    fontFamily: garamondFamily,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    letterSpacing: 0.5,
    color: AppColors.title,
  );

  /// Tag flutuante nos containers dourados.
  static const TextStyle tagLabel = TextStyle(
    fontFamily: sansFamily,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    color: AppColors.placeholder,
  );

  /// Corpo e hints.
  static const TextStyle body = TextStyle(
    fontFamily: sansFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.title,
  );

  /// Limiar do iOS Safari: ao focar um `<input>` com `font-size` menor que
  /// isto, ele dá zoom na página inteira — e o Flutter web replica o
  /// `TextStyle` do campo no `<input>` oculto que recebe o teclado.
  static const double iosNoZoomFontSize = 16;

  /// Campos de texto (busca da Home, busca dos Materiais favoritos).
  ///
  /// [body] com fonte no [iosNoZoomFontSize]: desde o Flutter 3.47 a viewport
  /// injetada pelo engine é `maximum-scale=5.0` (WCAG), então só o tamanho da
  /// fonte impede o auto-zoom do iOS — e, como o canvas captura os toques, o
  /// usuário não consegue desfazê-lo (`search_bar_input_font_size_test`).
  static const TextStyle input = TextStyle(
    fontFamily: sansFamily,
    fontWeight: FontWeight.w400,
    fontSize: iosNoZoomFontSize,
    color: AppColors.title,
  );

  /// Chips e labels de UI.
  static const TextStyle label = TextStyle(
    fontFamily: sansFamily,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: AppColors.title,
  );

  static TextStyle hint({bool italic = false}) => body.copyWith(
        color: AppColors.title.withValues(alpha: 0.55),
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );

  /// Placeholder dos campos que usam [input] — mesmo corpo, para o texto não
  /// mudar de tamanho entre vazio e preenchido.
  static TextStyle inputHint({bool italic = false}) =>
      hint(italic: italic).copyWith(fontSize: input.fontSize);

  static TextTheme textTheme(Color onSurface) => TextTheme(
        displaySmall: displayPlcpg,
        headlineSmall: headline,
        bodyMedium: body.copyWith(color: onSurface),
        bodySmall: body.copyWith(
          fontSize: 12,
          color: onSurface.withValues(alpha: 0.8),
        ),
        labelLarge: label,
        labelMedium: label.copyWith(fontSize: 12),
      );
}
