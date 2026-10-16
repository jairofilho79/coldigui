import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do Tour Integrado de Boas-Vindas do Coldigui.
///
/// Um percurso pedagógico em 4 passos apresentando a jornada do acervo ao culto:
/// 1. Pesquisa inteligente no catálogo.
/// 2. Escolha do formato (Partitura, Cifra, Gestos CIAs ou Letra).
/// 3. Adição e gerenciamento no Carrossel ativo de culto.
/// 4. Listas salvas e uso offline sem internet.
List<SpotlightGuideStep> buildWelcomeTourTutorialSteps(BuildContext context) {
  return [
    // 1. Pesquise um louvor na Home
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-search-bar',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: '1. Pesquise no Hinário',
          message:
              'Digite o **número**, o **título** ou qualquer **trecho da letra** para localizar instantaneamente hinos e cânticos no acervo.',
        ),
      ),
    ),

    // 2. Escolha o Formato Ideal
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-filter-chip-sample',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 10,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: '2. Formatos Especializados',
          message:
              'Toque no louvor para selecionar entre **Partitura**, **Cifra**, **Gestos para Crianças** ou **Letra**, com transposição de tom e autoscroll.',
        ),
      ),
    ),

    // 3. Adicione ao Carrossel Ativo
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-louvor-card-sample',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: '3. Monte seu Repertório de Culto',
          message:
              'Toque no botão **(+)** para incluir louvores no **Carrossel Ativo**, permitindo alternar rapidamente entre partituras durante a ministração.',
        ),
      ),
    ),

    // 4. Listas e Uso Offline
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-bottom-nav',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: '4. Repertório Sempre com Você',
          message:
              'Acesse a aba **Listas** para organizar playlists de ensaio e abra o **Armazenamento Offline** no Perfil para louvar **sem internet** em qualquer lugar!',
        ),
      ),
    ),
  ];
}
