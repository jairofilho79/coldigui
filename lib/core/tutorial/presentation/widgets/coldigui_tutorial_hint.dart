import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../theme/color_extensions.dart';

/// Balão de tutorial estilizado com a identidade visual do Coldigui / PLPCG.
///
/// Apresenta borda dourada, fundo litúrgico escuro, tipografia temática,
/// palavras-chave destacadas em negrito com tom dourado, e rótulos de navegação
/// em português (Voltar, Próximo, Concluir, Pular).
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

  static List<InlineSpan> _parseMarkdown(String text) {
    final spans = <InlineSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      if (i % 2 == 1) {
        // Ímpar: dentro de **...**
        spans.add(
          TextSpan(
            text: parts[i],
            style: const TextStyle(
              color: AppColors.goldLight,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else {
        // Par: texto normal
        spans.add(
          TextSpan(
            text: parts[i],
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.normal,
            ),
          ),
        );
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isLast = guide.isLast && guide.isLastItem;

    return SpotlightGuideBubbleHint(
      guide: guide,
      decoration: const SpotlightGuideBubbleDecoration(
        color: AppColors.background,
        borderRadius: 12,
        border: BorderSide(color: AppColors.gold, width: 1.5),
        boxShadow: AppColors.shadowLg,
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: '$title. ${message.replaceAll('**', '')}',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Passo ${guide.index + 1} de ${guide.total}',
                        style: const TextStyle(
                          color: AppColors.goldLight,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                          children: _parseMarkdown(message),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (showSkipButton)
                    TextButton(
                      onPressed: guide.finish,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            AppColors.textLight.withValues(alpha: 0.8),
                        textStyle: const TextStyle(fontSize: 13),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Pular'),
                    ),
                  if (!guide.isFirst)
                    TextButton(
                      onPressed: guide.previous,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            AppColors.textLight.withValues(alpha: 0.8),
                        textStyle: const TextStyle(fontSize: 13),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Voltar'),
                    ),
                  FilledButton(
                    onPressed: isLast ? guide.finish : guide.next,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.background,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(isLast ? 'Concluir' : 'Próximo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
