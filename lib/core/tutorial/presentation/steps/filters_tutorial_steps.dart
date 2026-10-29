import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial do Painel Avançado de Filtros ([FiltersPanel]).
List<SpotlightGuideStep> buildFiltersTutorialSteps(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context);
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
          title: l10n?.tutorialFiltersStep1Title ?? 'Filtro por Tonalidade',
          message:
              l10n?.tutorialFiltersStep1Message ??
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
          title: l10n?.tutorialFiltersStep2Title ?? 'Filtro por Ritmo',
          message:
              l10n?.tutorialFiltersStep2Message ??
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
          title: l10n?.tutorialFiltersStep3Title ?? 'Categorias e Tags de Culto',
          message:
              l10n?.tutorialFiltersStep3Message ??
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
          title: l10n?.tutorialFiltersStep4Title ?? 'Tipos de Materiais',
          message:
              l10n?.tutorialFiltersStep4Message ??
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
          title: l10n?.tutorialFiltersStep5Title ?? 'Limpar Filtros',
          message:
              l10n?.tutorialFiltersStep5Message ??
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
          title: l10n?.tutorialFiltersStep6Title ?? 'Ajuda de Filtros',
          message:
              l10n?.tutorialFiltersStep6Message ??
              'Toque neste ícone sempre que desejar rever as orientações sobre como **combinar filtros avançados**.',
        ),
      ),
    ),
  ];
}
