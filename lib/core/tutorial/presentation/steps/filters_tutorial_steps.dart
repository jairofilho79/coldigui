import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial do Painel Avançado de Filtros ([FiltersPanel]).
List<SpotlightGuideStep> buildFiltersTutorialSteps(
  BuildContext context,
) {
  return [
    // 1. Filtro por Tonalidade
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'filters-tonality-section',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Filtro por Tonalidade',
          message:
              'Filtre o acervo pela **tonalidade musical** (Dó, Ré, Mi...) e seus acidentes para encontrar louvores no tom exato da sua equipe.',
        ),
      ),
    ),

    // 2. Filtro por Ritmo
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'filters-rhythm-section',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Filtro por Ritmo',
          message:
              'Selecione compassos e ritmos específicos como **Valsa**, **Marcha**, **Básico** ou **Toada** para adequar o repertório ao culto.',
        ),
      ),
    ),

    // 3. Categorias e Tags de Culto
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'filters-category-section',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Categorias e Tags de Culto',
          message:
              'Refine os hinos por **ocasião de culto**, como **Comunhão**, **Ceia**, **Crianças** ou momentos devocionais.',
        ),
      ),
    ),

    // 4. Tipos de Materiais
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'filters-material-kind',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Tipos de Materiais',
          message:
              'Restrinja os resultados para exibir apenas louvores que possuam **Cifras**, **Partituras**, **Gestos CIAs** ou **Áudios** disponíveis.',
        ),
      ),
    ),

    // 5. Limpar Filtros
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'filters-clear-action',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Limpar Filtros',
          message:
              'Toque em **Limpar** para redefinir instantaneamente todos os filtros aplicados e visualizar o acervo completo.',
        ),
      ),
    ),

    // 6. Ajuda de Filtros
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'filters-info',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Ajuda de Filtros',
          message:
              'Toque neste ícone sempre que desejar rever as orientações sobre como **combinar filtros avançados**.',
        ),
      ),
    ),
  ];
}
