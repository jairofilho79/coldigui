import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Detalhes da Contribuição ([ContributionDetailScreen]).
List<SpotlightGuideStep> buildContributionDetailTutorialSteps(
  BuildContext context,
) {
  return [
    // 1. Título e Estado do Envio
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'contribution-detail-header',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Título e Estado do Envio',
          message:
              'Acompanhe o **título da contribuição** e seu status atual (**Em análise**, **Aprovada** ou **Recusada**).',
        ),
      ),
    ),

    // 2. Tipo de Contribuição
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'contribution-detail-kind',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Tipo de Contribuição',
          message:
              'Indica a categoria da colaboração enviada, como **Cifra**, **Letra**, **Partitura** ou **Correção de informações**.',
        ),
      ),
    ),

    // 3. Descrição e Observações
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'contribution-detail-body',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 10,
          padding: const EdgeInsets.all(6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Descrição e Observações',
          message:
              'Aqui você confere o **texto descritivo**, justificativas e links externos adicionados na submissão da proposta.',
        ),
      ),
    ),

    // 4. Campos Alterados (ignora se não for correção de metadados)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'contribution-detail-diff',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 10,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Campos Alterados',
          message:
              'Quando a contribuição propõe corrigir dados, veja a comparação direta entre o valor **atual** e o **proposto**.',
        ),
      ),
    ),

    // 5. Arquivos e Verificação Antivírus (ignora se não houver anexos)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'contribution-detail-files',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Arquivos e Verificação Antivírus',
          message:
              'Consulte a lista de **anexos enviados** e o status da verificação de segurança em tempo real (**Limpa**, **Verificando** ou **Bloqueada**).',
        ),
      ),
    ),

    // 6. Parecer da Moderação (ignora se ainda estiver pendente/sem nota)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'contribution-detail-decision',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Parecer da Moderação',
          message:
              'Quando a equipe do PLPCG avaliar o envio, o **parecer e justificativa dos revisores** serão exibidos nesta área.',
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
              'Sempre que tiver dúvidas sobre os detalhes da contribuição, toque neste **ícone (i)** para rever este tutorial passo a passo!',
        ),
      ),
    ),
  ];
}
