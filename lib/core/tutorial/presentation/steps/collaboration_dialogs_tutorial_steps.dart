import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial do diálogo de compartilhamento ([PlaylistShareSheet]).
List<SpotlightGuideStep> buildPlaylistShareTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Folheto Ilustrado
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'playlist-share-leaflet',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialCollaborationDialogsStep1Title ?? 'Folheto Ilustrado',
          message:
              l10n?.tutorialCollaborationDialogsStep1Message ??
              'Gera e compartilha uma **imagem visual com a lista dos louvores** acompanhada do link direto para visualização.',
        ),
      ),
    ),

    // 2. Link Direto
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'playlist-share-link',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialCollaborationDialogsStep2Title ?? 'Link Direto',
          message:
              l10n?.tutorialCollaborationDialogsStep2Message ??
              'Copia ou envia apenas o **link encurtado**, ideal para envio rápido em aplicativos de mensagens.',
        ),
      ),
    ),

    // 3. Botão de Ajuda
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'playlist-share-info',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialCollaborationDialogsStep3Title ?? 'Ajuda de Compartilhamento',
          message:
              l10n?.tutorialCollaborationDialogsStep3Message ??
              'Toque neste ícone para rever as opções de **compartilhamento de repertórios**.',
        ),
      ),
    ),
  ];
}

/// Passos do tutorial do diálogo de publicação na comunidade ([PublishPlaylistDialog]).
List<SpotlightGuideStep> buildPublishPlaylistTutorialSteps(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Categoria da Lista
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'publish-playlist-category',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialCollaborationDialogsStep4Title ?? 'Categoria da Lista',
          message:
              l10n?.tutorialCollaborationDialogsStep4Message ??
              'Classifique o repertório como **Evangelização**, **Aprendizado**, **Medleys** ou **Culto Especial** para facilitar a busca por outros irmãos.',
        ),
      ),
    ),

    // 2. Alcance do Repertório
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'publish-playlist-reach',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialCollaborationDialogsStep5Title ?? 'Alcance do Repertório',
          message:
              l10n?.tutorialCollaborationDialogsStep5Message ??
              'Marque como **pontual** para eventos esporádicos ou mantenha desmarcado se for uma seleção **usual para cultos regulares**.',
        ),
      ),
    ),

    // 3. Confirmação da Publicação
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'publish-playlist-confirm',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialCollaborationDialogsStep6Title ?? 'Publicação na Comunidade',
          message:
              l10n?.tutorialCollaborationDialogsStep6Message ??
              'Toque em **Publicar** para disponibilizar a lista na aba pública. A lista poderá ser acessada e importada por toda a igreja.',
        ),
      ),
    ),

    // 4. Botão de Ajuda
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'publish-playlist-info',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialCollaborationDialogsStep7Title ?? 'Ajuda de Publicação',
          message:
              l10n?.tutorialCollaborationDialogsStep7Message ??
              'Toque neste ícone para rever as instruções sobre a **publicação de repertórios** na comunidade.',
        ),
      ),
    ),
  ];
}

/// Passos do tutorial do diálogo de entrada em sala ao vivo ([JoinLiveRoomDialog]).
List<SpotlightGuideStep> buildJoinLiveRoomTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Campo de Entrada do Código ou Link
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'join-live-input',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialCollaborationDialogsStep8Title ?? 'Código ou Link da Sala',
          message:
              l10n?.tutorialCollaborationDialogsStep8Message ??
              'Digite ou cole o **código de 7 caracteres** ou a **URL completa** fornecida pelo dirigente da sala ao vivo.',
        ),
      ),
    ),

    // 2. Colar da Área de Transferência
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'join-live-paste',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 10,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialCollaborationDialogsStep9Title ?? 'Colar da Área de Transferência',
          message:
              l10n?.tutorialCollaborationDialogsStep9Message ??
              'Toque em **Colar** para preencher instantaneamente com o link que você acabou de copiar no WhatsApp ou mensagem.',
        ),
      ),
    ),

    // 3. Confirmar Entrada
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'join-live-confirm',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialCollaborationDialogsStep10Title ?? 'Conectar à Sala',
          message:
              l10n?.tutorialCollaborationDialogsStep10Message ??
              'Toque em **Entrar** para ingressar na transmissão e acompanhar as **mudanças de louvor em tempo real**.',
        ),
      ),
    ),

    // 4. Botão de Ajuda
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'join-live-info',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialCollaborationDialogsStep11Title ?? 'Ajuda da Sala ao Vivo',
          message:
              l10n?.tutorialCollaborationDialogsStep11Message ??
              'Toque neste ícone para rever as instruções de **sincronização como seguidor** de uma sala ao vivo.',
        ),
      ),
    ),
  ];
}
