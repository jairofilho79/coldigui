import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial do Gerenciador da Lista Ativa ([CarouselSelectionSheet]).
List<SpotlightGuideStep> buildCarouselSelectionTutorialSteps(
  BuildContext context,
) {
  return [
    // 1. Reordenar Repertório
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'active-list-reorder',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Reordenar Repertório',
          message:
              'Segure e arraste o ícone de **alça de ordenação** para mudar a sequência dos louvores em tempo real durante o culto ou ensaio.',
        ),
      ),
    ),

    // 2. Navegação Rápida
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'active-list-jump',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Navegação Rápida',
          message:
              'Toque no **corpo do louvor** para saltar imediatamente para ele no leitor de partituras ou cifras ativo.',
        ),
      ),
    ),

    // 3. Remover da Seleção
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'active-list-remove',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Remover da Seleção',
          message:
              'Toque no botão **×** para retirar o louvor da lista temporária de culto sem apagar suas playlists salvas.',
        ),
      ),
    ),

    // 4. Limpar ou Reiniciar Lista
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'active-list-clear',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Limpar ou Reiniciar Lista',
          message:
              'Use esta ação para **limpar a lista ativa** e iniciar uma nova seleção do zero ou descartar o rascunho atual.',
        ),
      ),
    ),

    // 5. Ajuda da Lista Ativa
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'active-list-info',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Ajuda da Lista Ativa',
          message:
              'Consulte este **guia rápido** sempre que tiver dúvidas sobre como reorganizar e operar seu repertório.',
        ),
      ),
    ),
  ];
}
