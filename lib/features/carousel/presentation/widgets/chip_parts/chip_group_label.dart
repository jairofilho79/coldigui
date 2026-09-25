import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Etiqueta dourada do gomo do amendoim — o que diferencia aquela versão do
/// grupo (spec louvores-agrupados §5, §6.2). Corta com «…» em
/// [maxTextWidth].
class ChipGroupLabel extends StatelessWidget {
  const ChipGroupLabel({required this.label, super.key});

  final String label;

  static const maxTextWidth = 128.0;

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
        constraints: const BoxConstraints(maxWidth: maxTextWidth),
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
