import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial do modo foco de gestos ([GestureFocusView]).
List<SpotlightGuideStep> buildGestureFocusTutorialSteps(BuildContext context) {
  return [
    // 1. Cartão do Gesto em Destaque
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'gesture-focus-card',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.all(8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Cartão do Gesto em Destaque',
          message:
              'Visualize o movimento do gesto em **tamanho ampliado**, com animação ou ilustração para fácil acompanhamento pelo regente.',
        ),
      ),
    ),

    // 2. Frase e Letra Disparadora
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'gesture-focus-trigger',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Frase & Letra Disparadora',
          message:
              'Acompanhe a letra associada, com destaque em **vermelho no gatilho** em que o gesto deve ser executado pelo grupo de louvor.',
        ),
      ),
    ),

    // 3. Navegação entre Gestos
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'gesture-focus-navigation',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Navegação entre Gestos',
          message:
              'Toque nas **laterais da tela**, **arraste para os lados** ou use as **setas do teclado (← e →)** para avançar ou retroceder os passos.',
        ),
      ),
    ),

    // 4. Próximo Gatilho no Rodapé
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'gesture-focus-next',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Próximo Gatilho',
          message:
              'Consulte no rodapé a **palavra ou frase do próximo gesto**, preparando a transição antes que ela aconteça.',
        ),
      ),
    ),

    // 5. Botão de Ajuda
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'gesture-focus-info',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Ajuda do Modo Foco',
          message:
              'Toque neste ícone para rever este **guia passo a passo** ou pressione **Esc** para fechar e retornar ao leitor a qualquer momento.',
        ),
      ),
    ),
  ];
}
