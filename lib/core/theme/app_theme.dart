import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'color_extensions.dart';

/// Tema Material 3 — paleta Coletânea Digital (§6 MAPEAMENTO).
///
/// Configura tipografia Open Sans default, chips pill, inputs com borda gold
/// e cards creme. Consumido por [ColdiguiApp] via `theme: AppTheme.light`.
abstract final class AppTheme {
  static const double _borderRadius = 8;
  static const double _chipRadius = 24;

  /// Tema claro padrão do app.
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.title,
      onPrimary: AppColors.textLight,
      secondary: AppColors.gold,
      onSecondary: AppColors.title,
      surface: AppColors.card,
      onSurface: AppColors.title,
      error: AppColors.offlineMissing,
      onError: AppColors.textLight,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.sansFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.textTheme(AppColors.title),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.displayPlcpg,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.gold,
        thickness: 1,
        space: 1,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.gold, width: 2),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: AppTypography.hint(italic: true),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.goldLight, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.gold.withValues(alpha: 0.25),
        disabledColor: const Color(0xFF9CA3AF),
        labelStyle: AppTypography.label,
        secondaryLabelStyle: AppTypography.label.copyWith(
          color: AppColors.textLight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_chipRadius),
          side: const BorderSide(color: AppColors.title, width: 1.5),
        ),
        side: const BorderSide(color: AppColors.title, width: 1.5),
        showCheckmark: false,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppTypography.body,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.card,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
