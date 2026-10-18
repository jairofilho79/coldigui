import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da Central de Atalhos de Teclado ([AppShortcutsDialog]).
List<SpotlightGuideStep> buildAppShortcutsTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Abas de Categorias
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'shortcuts-categories-tabs',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialAppShortcutsStep1Title ?? 'Categorias de Atalhos',
          message:
              l10n?.tutorialAppShortcutsStep1Message ??
              'Navegue entre as abas para explorar comandos agrupados por contexto: **Navegação & Busca**, **Repertório & Áudio**, **Partituras** e **Cifras & Gestos**.',
        ),
      ),
    ),

    // 2. Lista de Atalhos e Teclas
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'shortcuts-list-items',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialAppShortcutsStep2Title ?? 'Comandos de Alta Produtividade',
          message:
              l10n?.tutorialAppShortcutsStep2Message ??
              'Consulte as teclas de atalho e suas ações correspondentes. Os selos laterais destacam os **contextos e leitores em que cada comando atua**.',
        ),
      ),
    ),

    // 3. Dica do Rodapé (?)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'shortcuts-footer-tip',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 10,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialAppShortcutsStep3Title ?? 'Acesso Rápido com a Tecla ?',
          message:
              l10n?.tutorialAppShortcutsStep3Message ??
              'Pressione **?** (ou **Shift + /**) em qualquer tela do app para abrir esta **central de atalhos instantaneamente** no Desktop e Web.',
        ),
      ),
    ),

    // 4. Botão de Ajuda
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'shortcuts-info-button',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialAppShortcutsStep4Title ?? 'Ajuda da Central de Atalhos',
          message:
              l10n?.tutorialAppShortcutsStep4Message ??
              'Toque neste ícone para rever as instruções sobre os **comandos e atalhos rápidos** do PLPCG.',
        ),
      ),
    ),
  ];
}
