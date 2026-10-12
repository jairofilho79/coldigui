import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../theme/color_extensions.dart';

/// Balão de tutorial estilizado com a identidade visual do Coldigui / PLPCG.
///
/// Apresenta borda dourada, fundo litúrgico escuro, tipografia temática
/// e rótulos de navegação em português (Voltar, Próximo, Concluir, Pular).
class ColdiguiTutorialHint extends StatelessWidget {
  const ColdiguiTutorialHint({
    super.key,
    required this.guide,
    required this.title,
    required this.message,
    this.showSkipButton = true,
  });

  final SpotlightGuideStepContext guide;
  final String title;
  final String message;
  final bool showSkipButton;

  @override
  Widget build(BuildContext context) {
    return SpotlightGuideTextHint(
      guide: guide,
      title: title,
      message: message,
      progressLabel: 'Passo ${guide.index + 1} de ${guide.total}',
      showSkipButton: showSkipButton,
      backLabel: 'Voltar',
      nextLabel: 'Próximo',
      doneLabel: 'Concluir',
      skipLabel: 'Pular',
      titleStyle: const TextStyle(
        color: AppColors.gold,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      messageStyle: const TextStyle(
        color: AppColors.textLight,
        fontSize: 13.5,
        height: 1.35,
      ),
      progressStyle: const TextStyle(
        color: AppColors.goldLight,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      primaryButtonStyle: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.background,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      secondaryButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.textLight.withValues(alpha: 0.8),
        textStyle: const TextStyle(fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      decoration: const SpotlightGuideBubbleDecoration(
        color: AppColors.background,
        borderRadius: 12,
        border: BorderSide(color: AppColors.gold, width: 1.5),
        boxShadow: AppColors.shadowLg,
      ),
    );
  }
}
