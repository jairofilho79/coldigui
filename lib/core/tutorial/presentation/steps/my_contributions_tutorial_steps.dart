import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Minhas Contribuições ([MyContributionsScreen]).
List<SpotlightGuideStep> buildMyContributionsTutorialSteps(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Prompt de Login (quando não autenticado)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'my-contributions-signin-prompt',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 14,
          padding: const EdgeInsets.all(8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialMyContributionsStep1Title ?? 'Identificação Necessária',
          message:
              l10n?.tutorialMyContributionsStep1Message ??
              'Faça login com sua **conta Google** para acessar o histórico de sugestões, correções e materiais que você enviou.',
        ),
      ),
    ),

    // 2. Estado Vazio (quando não há envios ainda)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'my-contributions-empty',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialMyContributionsStep2Title ?? 'Nenhum Envio Ainda',
          message:
              l10n?.tutorialMyContributionsStep2Message ??
              'Todas as **sugestões de letras, partituras ou correções** enviadas por você através do botão **Contribuir** aparecerão listadas nesta tela.',
        ),
      ),
    ),

    // 3. Item da Contribuição
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'my-contributions-item',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialMyContributionsStep3Title ?? 'Histórico de Envios',
          message:
              l10n?.tutorialMyContributionsStep3Message ??
              'Visualize o título, tipo de material e data da sua colaboração. Toque em qualquer linha para abrir a **tela de detalhes** e ver anotações da equipe.',
        ),
      ),
    ),

    // 4. Status da Análise
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'my-contributions-status',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialMyContributionsStep4Title ?? 'Status da Análise',
          message:
              l10n?.tutorialMyContributionsStep4Message ??
              'Acompanhe o andamento da sua solicitação: **pendente**, **em análise**, **aprovada** ou **rejeitada**.',
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
          title: l10n?.tutorialMyContributionsStep5Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialMyContributionsStep5Message ??
              'Toque no **ícone (i)** a qualquer momento para rever este guia ou aprender mais sobre as telas do aplicativo!',
        ),
      ),
    ),
  ];
}
