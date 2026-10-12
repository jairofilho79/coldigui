import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela inicial / Pesquisador ([HomeScreen]).
List<SpotlightGuideStep> buildHomeTutorialSteps(BuildContext context) {
  return [
    // 1. Barra de pesquisa
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-search-bar',
        placement: SpotlightGuidePlacement.bottom,
        targetDecoration: const SpotlightGuideTargetDecoration(
          padding: EdgeInsets.all(4),
          shape: SpotlightGuideRoundedRectShape(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Pesquisa Inteligente',
          message:
              'Digite o número do louvor, o título ou parte da letra para localizá-lo instantaneamente.',
        ),
      ),
    ),

    // 2. Painel de Filtros
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-filters-panel',
        placement: SpotlightGuidePlacement.bottom,
        targetDecoration: const SpotlightGuideTargetDecoration(
          padding: EdgeInsets.all(4),
          shape: SpotlightGuideRoundedRectShape(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Filtros do Catálogo',
          message:
              'Refine sua busca por tom musical, ritmo, categorias/tags ou tipo de material (partitura, cifra, áudio).',
        ),
      ),
    ),

    // 3. Barra de navegação inferior (ou rail no desktop)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-bottom-nav',
        placement: SpotlightGuidePlacement.top,
        targetDecoration: const SpotlightGuideTargetDecoration(
          padding: EdgeInsets.all(6),
          shape: SpotlightGuideRoundedRectShape(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Navegação Principal',
          message:
              'Alterne facilmente entre o Pesquisador de Louvores, suas Listas e o seu Perfil.',
        ),
      ),
    ),

    // 4. Ícone de ajuda (i)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'app-info-button',
        placement: SpotlightGuidePlacement.bottom,
        targetDecoration: const SpotlightGuideTargetDecoration(
          padding: EdgeInsets.all(4),
          shape: SpotlightGuideRoundedRectShape(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Tutorial Sempre Disponível',
          message:
              'Sempre que tiver dúvidas sobre como usar qualquer tela, toque neste ícone (i) para rever as explicações.',
        ),
      ),
    ),
  ];
}
