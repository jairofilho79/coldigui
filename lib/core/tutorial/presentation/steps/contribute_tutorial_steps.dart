import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Contribuir ([ContributeScreen]).
List<SpotlightGuideStep> buildContributeTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Contexto do Envio / Louvor Vinculado
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'contribute-target-banner',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialContributeStep1Title ?? 'Contexto do Envio',
          message:
              l10n?.tutorialContributeStep1Message ??
              'Identifique se sua colaboração está **vinculada a um louvor específico** ou se é uma **sugestão geral** para o aplicativo.',
        ),
      ),
    ),

    // 2. Descrição / Corpo da Sugestão
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'contribute-body-field',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 14,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialContributeStep2Title ?? 'Descrição da Sugestão',
          message:
              l10n?.tutorialContributeStep2Message ??
              'Descreva detalhadamente o **problema encontrado**, **correção de letra ou tom**, ou a **melhoria** que você gostaria de propor.',
        ),
      ),
    ),

    // 3. Diagnóstico do Aparelho
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'contribute-diagnostics',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialContributeStep3Title ?? 'Diagnóstico do Aparelho',
          message:
              l10n?.tutorialContributeStep3Message ??
              'Mantenha ativado para enviar **dados técnicos anônimos** (sistema, navegador, resolução), acelerando a resolução de bugs.',
        ),
      ),
    ),

    // 4. Anexos e Links
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'contribute-attachments',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialContributeStep4Title ?? 'Anexos e Links',
          message:
              l10n?.tutorialContributeStep4Message ??
              'Adicione **arquivos de apoio** (áudios, partituras ou capturas até 32 MB) e **links** do YouTube ou Google Drive.',
        ),
      ),
    ),

    // 5. Botão Enviar / Login
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'contribute-submit-button',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 24,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialContributeStep5Title ?? 'Envio da Contribuição',
          message:
              l10n?.tutorialContributeStep5Message ??
              'Toque em **Enviar** para submeter seu relato. Se não estiver conectado, entre com sua **conta Google** para enviar.',
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
          title: l10n?.tutorialContributeStep6Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialContributeStep6Message ??
              'Toque neste ícone a qualquer momento para rever este **guia passo a passo** da tela de envio de sugestões.',
        ),
      ),
    ),
  ];
}
