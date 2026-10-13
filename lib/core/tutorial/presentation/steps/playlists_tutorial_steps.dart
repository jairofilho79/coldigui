import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Listas e Repertórios ([PlaylistsScreen]).
List<SpotlightGuideStep> buildPlaylistsTutorialSteps(BuildContext context) {
  return [
    // 1. Abas de Repertório
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'playlists-tabs',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Abas de Repertório',
          message:
              'Alterne entre suas listas **Não Salvas** (seleções rápidas de ensaio), listas **Salvas** (repertórios guardados e sincronizados) e **Favoritas** (para acesso rápido).',
        ),
      ),
    ),

    // 2. Importar Lista
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'playlists-import-button',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 24,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Importar Lista',
          message:
              'Recebeu uma lista compartilhada? Toque em **Importar lista** e cole o link ou código recebido para carregar os louvores no seu aplicativo.',
        ),
      ),
    ),

    // 3. Sala ao Vivo
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'playlists-live-room-button',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 24,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Sala ao Vivo',
          message:
              'Abra uma sala ou conecte-se ao ensaio da igreja. Todos os músicos acompanham a **troca de louvores em tempo real** durante a ministração.',
        ),
      ),
    ),

    // 4. Como Criar Novas Listas
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-bottom-nav',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.all(6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Criar Novas Listas',
          message:
              'Para montar uma nova lista, vá ao **Pesquisador** e toque no botão **"+"** de qualquer louvor ou versão de partitura.',
        ),
      ),
    ),

    // 5. Ajuda & Tutoriais
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
              'Toque no ícone **(i)** sempre que tiver dúvidas sobre como utilizar qualquer tela do aplicativo!',
        ),
      ),
    ),
  ];
}
