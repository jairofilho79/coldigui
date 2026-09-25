import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Etiqueta dourada do gomo do amendoim — o que diferencia aquela versão do
/// grupo (spec louvores-agrupados §5, §6.2). Corta com «…» em
/// [textWidthLimit], que o chip calcula com [maxTextWidthFor].
class ChipGroupLabel extends StatelessWidget {
  const ChipGroupLabel({
    required this.label,
    this.textWidthLimit = maxTextWidth,
    super.key,
  });

  final String label;

  /// Largura máxima do texto (sem o padding/borda da pílula).
  final double textWidthLimit;

  /// Teto da largura do texto — o valor do mock (cartão de 358).
  static const maxTextWidth = 128.0;

  /// Piso: abaixo disso a etiqueta vira só «…» e deixa de dizer algo.
  static const minTextWidth = 64.0;

  /// Fração da linha de conteúdo que a etiqueta pode ocupar.
  static const widthFraction = 0.4;

  /// Largura máxima do texto para uma linha de conteúdo de largura
  /// [rowWidth]: `clamp(0.4 × W, 64, 128)`. No cartão do mock (W≈322) dá
  /// o teto de 128; em celular estreito encolhe e sobra mais para o título.
  static double maxTextWidthFor(double rowWidth) =>
      (widthFraction * rowWidth).clamp(minTextWidth, maxTextWidth);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: textWidthLimit),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label.copyWith(
            fontSize: 10,
            height: 1.2,
            color: AppColors.goldLight,
          ),
        ),
      ),
    );
  }
}
