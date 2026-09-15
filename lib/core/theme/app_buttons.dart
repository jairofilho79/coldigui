import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'color_extensions.dart';

/// Botões para o **fundo escuro** do scaffold ([AppColors.background]).
///
/// O tema Material deriva os botões do `colorScheme` (primary = [AppColors.title],
/// o vinho dos cards), que não se lê sobre o scaffold. Aqui os dois níveis
/// partilham a mesma borda dourada (aparência *outlined*) e diferem só no
/// preenchimento — ver «Contraste» em [AppColors].
abstract final class AppButtons {
  static const double _radius = 8;
  static const _border = BorderSide(color: AppColors.gold, width: 2);
  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(_radius)),
  );
  static const _padding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);

  /// Ação principal: fundo dourado, texto [AppColors.title].
  static final ButtonStyle onDarkPrimary = OutlinedButton.styleFrom(
    backgroundColor: AppColors.gold,
    foregroundColor: AppColors.title,
    disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
    disabledForegroundColor: AppColors.title.withValues(alpha: 0.6),
    side: _border,
    shape: _shape,
    padding: _padding,
    textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
  );

  /// Ação secundária: transparente, texto [AppColors.textLight].
  static final ButtonStyle onDarkSecondary = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textLight,
    disabledForegroundColor: AppColors.textLight.withValues(alpha: 0.5),
    side: _border,
    shape: _shape,
    padding: _padding,
    textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
  );
}
