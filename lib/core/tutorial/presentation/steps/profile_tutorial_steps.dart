import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Perfil e Ajustes ([ProfileScreen]).
List<SpotlightGuideStep> buildProfileTutorialSteps(BuildContext context) {
  return [
    // 1. Painel de Conta / Sincronização
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'profile-account-panel',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Conta & Sincronização',
          message:
              'Conecte sua conta **Google** para sincronizar suas **listas de louvores**, preferências e materiais favoritos automaticamente entre seus aparelhos.',
        ),
      ),
    ),

    // 2. Biblioteca Completa
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'profile-library-tile',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 10,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Biblioteca Completa',
          message:
              'Acesse a **Biblioteca** para explorar o catálogo completo em formato de **lista paginada**, com filtros detalhados de instrumentos e categorias.',
        ),
      ),
    ),

    // 3. Contribuir com o Hinário
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'profile-contribute-tile',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 10,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Contribuir',
          message:
              'Envie **novas partituras**, cifras, gestos ou correções de letras. A colaboração da irmandade mantém o acervo sempre atualizado e preciso!',
        ),
      ),
    ),

    // 4. Armazenamento Offline
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'profile-offline-tile',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 10,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Modo Offline',
          message:
              'Baixe os arquivos de partituras e letras para usar o aplicativo **sem internet** durante cultos e ensaios com total rapidez.',
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
              'Toque no ícone **(i)** sempre que quiser rever as instruções e dicas desta tela!',
        ),
      ),
    ),
  ];
}
