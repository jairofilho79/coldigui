import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Materiais Favoritos ([FavoriteMaterialKindsScreen]).
List<SpotlightGuideStep> buildFavoriteMaterialKindsTutorialSteps(
  BuildContext context,
) {
  return [
    // 1. Introdução e Limite (quando autenticado)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'fav-intro-help',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Prioridade de Materiais',
          message:
              'Defina até **4 materiais favoritos** para priorizar seus instrumentos e vozes no topo dos resultados de busca e no leitor.',
        ),
      ),
    ),

    // 2. Seção de Favoritos Atuais e Reordenação
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'fav-current-section',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Seus Favoritos e Ordem',
          message:
              'Acompanhe seus materiais selecionados. Arraste pela **alça lateral** para definir a prioridade, alterne o **formato preferido** ou toque no **(X)** para remover.',
        ),
      ),
    ),

    // 3. Campo de Busca e Adição
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'fav-search-field',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Adicionar Novos Materiais',
          message:
              'Busque por instrumentos (ex: **violão**, **baixo**, **órgão**) ou vozes e toque no ícone **(+)** para adicioná-los à sua lista de prioridades.',
        ),
      ),
    ),

    // 4. Prompt de Login (quando não autenticado)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'fav-signin-prompt',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 14,
          padding: const EdgeInsets.all(8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Sincronização na Nuvem',
          message:
              'Entre com sua **conta Google** para salvar e sincronizar suas preferências de materiais em qualquer aparelho.',
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
              'Toque no **ícone (i)** a qualquer momento para rever este guia ou aprender mais sobre os recursos do aplicativo!',
        ),
      ),
    ),
  ];
}
