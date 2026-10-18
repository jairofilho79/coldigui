import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Detalhes da Contribuição ([ContributionDetailScreen]).
List<SpotlightGuideStep> buildContributionDetailTutorialSteps(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context);
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
          title: l10n?.tutorialContributionDetailStep1Title ?? 'Título e Estado do Envio',
          message:
              l10n?.tutorialContributionDetailStep1Message ??
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
          title: l10n?.tutorialContributionDetailStep2Title ?? 'Tipo de Contribuição',
          message:
              l10n?.tutorialContributionDetailStep2Message ??
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
          title: l10n?.tutorialContributionDetailStep3Title ?? 'Descrição e Observações',
          message:
              l10n?.tutorialContributionDetailStep3Message ??
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
          title: l10n?.tutorialContributionDetailStep4Title ?? 'Campos Alterados',
          message:
              l10n?.tutorialContributionDetailStep4Message ??
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
          title: l10n?.tutorialContributionDetailStep5Title ?? 'Arquivos e Verificação Antivírus',
          message:
              l10n?.tutorialContributionDetailStep5Message ??
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
          title: l10n?.tutorialContributionDetailStep6Title ?? 'Parecer da Moderação',
          message:
              l10n?.tutorialContributionDetailStep6Message ??
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
          title: l10n?.tutorialContributionDetailStep7Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialContributionDetailStep7Message ??
              'Sempre que tiver dúvidas sobre os detalhes da contribuição, toque neste **ícone (i)** para rever este tutorial passo a passo!',
        ),
      ),
    ),
  ];
}
