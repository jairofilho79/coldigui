import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Detalhes do Louvor ([PraiseScreen]).
List<SpotlightGuideStep> buildPraiseTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Informações do Louvor
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'praise-header',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialPraiseStep1Title ?? 'Informações do Louvor',
          message:
              l10n?.tutorialPraiseStep1Message ??
              'Veja o **número** e o **título** do louvor. Toque em **Compartilhar** para copiar o link direto ou em **Sugerir melhoria** para nos enviar correções.',
        ),
      ),
    ),

    // 2. Versões Relacionadas (ignora se o louvor não tiver variantes)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'praise-related-bar',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialPraiseStep2Title ?? 'Versões Relacionadas',
          message:
              l10n?.tutorialPraiseStep2Message ??
              'Quando houver diferentes **arranjos, tonalidades ou variantes**, você pode alternar facilmente entre elas tocando nos botões de louvores relacionados.',
        ),
      ),
    ),

    // 3. Materiais e Partituras
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'praise-materials-section',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialPraiseStep3Title ?? 'Materiais e Partituras',
          message:
              l10n?.tutorialPraiseStep3Message ??
              'Acesse todas as **partituras**, **cifras**, **gestos** e **áudios** disponíveis para este louvor. Toque em um item para abrir ou no **+** para adicioná-lo à sua lista ativa.',
        ),
      ),
    ),

    // 4. Letra e Metadados
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'praise-lyrics-section',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialPraiseStep4Title ?? 'Letra e Metadados',
          message:
              l10n?.tutorialPraiseStep4Message ??
              'Consulte a **letra completa** do louvor, ajuste o tamanho da fonte, copie o texto ou toque no botão de reprodução para abrir no **leitor dedicado** com rolagem automática.',
        ),
      ),
    ),

    // 5. Ícone de ajuda (i)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'app-info-button',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialPraiseStep5Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialPraiseStep5Message ??
              'Sempre que tiver dúvidas sobre os detalhes do louvor, toque neste **ícone (i)** para rever este tutorial passo a passo!',
        ),
      ),
    ),
  ];
}
