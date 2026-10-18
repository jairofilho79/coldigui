import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Sala ao Vivo ([LiveRoomScreen]).
List<SpotlightGuideStep> buildLiveRoomTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Código e QR Code da Sala (modo líder)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'live-room-qr',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.all(8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLiveRoomStep1Title ?? 'Código e QR Code da Sala',
          message:
              l10n?.tutorialLiveRoomStep1Message ??
              'Os participantes podem ler este **código QR** com a câmera do celular ou acessar o **link direto** para acompanhar o culto.',
        ),
      ),
    ),

    // 2. Ações de Compartilhamento (modo líder)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'live-room-actions',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.all(6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLiveRoomStep2Title ?? 'Compartilhar e Gerenciar',
          message:
              l10n?.tutorialLiveRoomStep2Message ??
              'Copie ou **compartilhe o link** da transmissão com o grupo ou toque em **gerar novo link** caso precise redefinir o acesso.',
        ),
      ),
    ),

    // 3. Participantes Conectados (modo líder)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'live-room-viewers',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLiveRoomStep3Title ?? 'Participantes Conectados',
          message:
              l10n?.tutorialLiveRoomStep3Message ??
              'Acompanhe em tempo real o **número de irmãos** que estão sintonizados e seguindo as cifras e letras na sua sala.',
        ),
      ),
    ),

    // 4. Finalizar Transmissão (modo líder transmitindo)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'live-room-end-button',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLiveRoomStep4Title ?? 'Finalizar Transmissão',
          message:
              l10n?.tutorialLiveRoomStep4Message ??
              'Toque em **Encerrar** para concluir a sessão ao vivo com os participantes e retornar para as suas listas.',
        ),
      ),
    ),

    // 5. Status da Transmissão (modo seguidor/consumidor)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'live-room-status-card',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.all(12),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLiveRoomStep5Title ?? 'Status da Transmissão',
          message:
              l10n?.tutorialLiveRoomStep5Message ??
              'Acompanhe o andamento da sessão: veja se o líder está **ao vivo**, aguardando o culto ou se a conexão está **sincronizando**.',
        ),
      ),
    ),

    // 6. Ações do Seguidor (Guardar Cópia após encerramento)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'live-room-consumer-actions',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.all(6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLiveRoomStep6Title ?? 'Guardar Cópia',
          message:
              l10n?.tutorialLiveRoomStep6Message ??
              'Ao fim do culto, toque em **Guardar cópia** para salvar a lista de louvores executada diretamente nas suas listas pessoais.',
        ),
      ),
    ),

    // 7. Ícone de ajuda (i)
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
          title: l10n?.tutorialLiveRoomStep7Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialLiveRoomStep7Message ??
              'Toque neste ícone a qualquer momento para rever este **guia passo a passo** da sala ao vivo.',
        ),
      ),
    ),
  ];
}
