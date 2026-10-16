import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../theme/color_extensions.dart';
import '../providers/tutorial_preferences_provider.dart';

/// Layer customizada que força a limpeza transparente do furo do alvo via
/// [BlendMode.clear] (saveLayer) em vez de [Path.combine], garantindo que o
/// elemento destacado não fique escurecido nem com blur residual na Web/CanvasKit.
class SpotlightWebClearHoleLayer extends SpotlightGuideTargetLayer {
  const SpotlightWebClearHoleLayer();

  @override
  void paint(Canvas canvas, SpotlightGuideTargetLayerContext context) {}
}

/// Cria a decoração padrão com anel dourado e furo 100% transparente do Coldigui.
SpotlightGuideTargetDecoration coldiguiTargetDecoration({
  EdgeInsetsGeometry padding = const EdgeInsets.all(4),
  double borderRadius = 12,
  double ringWidth = 2.5,
  double ringOutset = 2,
}) {
  return SpotlightGuideTargetDecoration(
    padding: padding,
    shape: SpotlightGuideRoundedRectShape(
      borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
    ),
    layers: [
      const SpotlightWebClearHoleLayer(),
      SpotlightGuideTargetRingLayer(
        color: AppColors.gold,
        width: ringWidth,
        outset: ringOutset,
      ),
    ],
  );
}

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
    this.showDismissForeverButton = true,
    this.onDismissForever,
  });

  final SpotlightGuideStepContext guide;
  final String title;
  final String message;
  final bool showSkipButton;
  final bool showDismissForeverButton;
  final VoidCallback? onDismissForever;

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
                  if (showDismissForeverButton)
                    TextButton(
                      key: const ValueKey('tutorial-hint-dismiss-forever'),
                      onPressed: () {
                        onDismissForever?.call();
                        try {
                          final container =
                              ProviderScope.containerOf(context, listen: false);
                          container
                              .read(tutorialPreferencesProvider.notifier)
                              .setDismissAll(true);
                        } catch (_) {}
                        guide.finish();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor:
                            AppColors.textLight.withValues(alpha: 0.65),
                        textStyle: const TextStyle(fontSize: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Não mostrar novamente'),
                    ),
                  if (showSkipButton)
                    TextButton(
                      key: const ValueKey('tutorial-hint-skip'),
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
                      key: const ValueKey('tutorial-hint-previous'),
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
                    key: const ValueKey('tutorial-hint-next'),
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
