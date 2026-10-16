import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Listas Públicas ([PublicPlaylistsScreen]).
List<SpotlightGuideStep> buildPublicPlaylistsTutorialSteps(
  BuildContext context,
) {
  return [
    // 1. Banner de Autenticação / Nome de Usuário (quando necessário)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'public-playlists-auth-banner',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 14,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Seu Nome de Usuário',
          message:
              'Faça login com sua conta Google e crie seu **@usuário** para compartilhar suas próprias listas públicas com a igreja.',
        ),
      ),
    ),

    // 2. Barra de Busca de Usuários
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'public-playlists-search-bar',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Buscar Irmãos e Equipes',
          message:
              'Digite o **@usuário** de outros membros da equipe para localizar suas listas públicas e repertórios compartilhados.',
        ),
      ),
    ),

    // 3. Resultados e Importação
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'public-playlists-results',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Listas e Importação',
          message:
              'Nos resultados, visualize as listas publicadas e toque em **importar** para adicionar os louvores à sua lista ativa.',
        ),
      ),
    ),

    // 4. Ícone de ajuda (i)
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
              'Toque no **ícone (i)** a qualquer momento para rever este guia passo a passo!',
        ),
      ),
    ),
  ];
}
