import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela Sobre ([AboutScreen]).
List<SpotlightGuideStep> buildAboutTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Quem somos
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'about-who-we-are',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 14,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialAboutStep1Title ?? 'Quem Somos',
          message:
              l10n?.tutorialAboutStep1Message ??
              'Conheça a história e a equipe por trás da aplicação. Uma iniciativa **100% gratuita** e colaborativa desenvolvida para auxiliar equipes de louvor.',
        ),
      ),
    ),

    // 2. Nosso Objetivo
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'about-mission',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 14,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialAboutStep2Title ?? 'Nosso Objetivo',
          message:
              l10n?.tutorialAboutStep2Message ??
              'O propósito central é facilitar o acesso a **partituras, cifras, gestos e áudios**, com funcionamento **offline** garantido mesmo em locais sem internet.',
        ),
      ),
    ),

    // 3. Ícone de ajuda (i)
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
          title: l10n?.tutorialAboutStep3Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialAboutStep3Message ??
              'Toque no **ícone (i)** sempre que quiser rever este guia ou conferir instruções detalhadas em qualquer tela do aplicativo!',
        ),
      ),
    ),
  ];
}
