import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial do Reprodutor de Áudio Coldigom ([AudioPlayerScreen]).
List<SpotlightGuideStep> buildAudioTutorialSteps(BuildContext context) {
  return [
    // 1. Informações da Faixa
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'audio-track-info',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.all(12),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Informações da Faixa',
          message:
              'Visualize o **título**, **número**, **autor** e a **classificação** do louvor ou áudio em reprodução.',
        ),
      ),
    ),

    // 2. Ações e Sincronização
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'audio-quick-actions',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Ações e Sincronização',
          message:
              'Acesse a **partitura vinculada**, adicione **marcadores de áudio**, ative o modo **seguir o áudio** no leitor e ajuste a **velocidade de reprodução**.',
        ),
      ),
    ),

    // 3. Barra de Progresso
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'audio-seek-bar',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Barra de Progresso',
          message:
              'Acompanhe o **tempo atual**, a **duração total** e arraste a barra para avançar ou retroceder. Os **marcadores** cadastrados aparecem destacados na linha do tempo.',
        ),
      ),
    ),

    // 4. Controles de Reprodução
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'audio-transport-controls',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Controles de Reprodução',
          message:
              'Controle o áudio com **Play/Pause**, pule para a **faixa anterior ou seguinte** e avance ou retroceder rapidamente em **10 segundos**.',
        ),
      ),
    ),

    // 5. Marcadores de Estudo (ignora se nenhuma faixa estiver carregada)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'audio-flag-list',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Marcadores de Estudo',
          message:
              'Veja todos os **marcadores com marcação de tempo** adicionados à faixa. Toque em qualquer marcador para ir direto àquele ponto do ensaio.',
        ),
      ),
    ),

    // 6. Ícone de ajuda (i)
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
              'Sempre que tiver dúvidas sobre o reprodutor de áudio, toque neste **ícone (i)** para rever este tutorial passo a passo!',
        ),
      ),
    ),
  ];
}
