import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Sala ao Vivo ([LiveRoomScreen]).
List<SpotlightGuideStep> buildLiveRoomTutorialSteps(BuildContext context) {
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
          title: 'Código e QR Code da Sala',
          message:
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
          title: 'Compartilhar e Gerenciar',
          message:
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
          title: 'Participantes Conectados',
          message:
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
          title: 'Finalizar Transmissão',
          message:
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
          title: 'Status da Transmissão',
          message:
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
          title: 'Guardar Cópia',
          message:
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
          title: 'Ajuda & Tutoriais',
          message:
              'Toque neste ícone a qualquer momento para rever este **guia passo a passo** da sala ao vivo.',
        ),
      ),
    ),
  ];
}
