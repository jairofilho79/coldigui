import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Minhas Contribuições ([MyContributionsScreen]).
List<SpotlightGuideStep> buildMyContributionsTutorialSteps(
  BuildContext context,
) {
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
          title: 'Identificação Necessária',
          message:
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
          title: 'Nenhum Envio Ainda',
          message:
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
          title: 'Histórico de Envios',
          message:
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
          title: 'Status da Análise',
          message:
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
          title: 'Ajuda & Tutoriais',
          message:
              'Toque no **ícone (i)** a qualquer momento para rever este guia ou aprender mais sobre as telas do aplicativo!',
        ),
      ),
    ),
  ];
}
