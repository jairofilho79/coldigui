import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial do Leitor de Cifras ChordPro ([ChordReaderScreen]).
List<SpotlightGuideStep> buildChordsTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Transposição de Tom
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'chords-transpose-controls',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialChordsStep1Title ?? 'Transposição de Tom',
          message:
              l10n?.tutorialChordsStep1Message ??
              'Suba ou desça o tom da música em **semitons** usando os botões **+** e **-** (ou pelo teclado). Toque no número do tom para **restaurar o tom original**.',
        ),
      ),
    ),

    // 2. Tamanho da Fonte
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'chords-font-size-controls',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialChordsStep2Title ?? 'Tamanho da Fonte',
          message:
              l10n?.tutorialChordsStep2Message ??
              'Ajuste o **tamanho do texto** e das cifras para melhor leitura na sua tela através dos botões de **diminuir** e **aumentar fonte**.',
        ),
      ),
    ),

    // 3. Rolagem Automática (Autoscroll)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'chords-autoscroll-controls',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialChordsStep3Title ?? 'Rolagem Automática',
          message:
              l10n?.tutorialChordsStep3Message ??
              'Inicie a **rolagem automática** (tecla **S**) para acompanhar a música sem usar as mãos. Ajuste a **velocidade** no ícone de velocímetro ou pelas teclas **[** e **]**.',
        ),
      ),
    ),

    // 4. Tema e Tela Cheia
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'chords-mode-controls',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialChordsStep4Title ?? 'Tema e Tela Cheia',
          message:
              l10n?.tutorialChordsStep4Message ??
              'Alterne entre o **modo claro e escuro** para melhor visibilidade no ambiente, e use **tela cheia** (tecla **F**) para focar exclusivamente na cifra.',
        ),
      ),
    ),

    // 5. Área da Cifra e Diagramação
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'chords-content-view',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialChordsStep5Title ?? 'Leitura e Diagramação',
          message:
              l10n?.tutorialChordsStep5Message ??
              'Em telas largas a **cifra** é diagramada automaticamente em **duas colunas**. Ao tocar ou rolar manualmente na tela, o autoscroll é **pausado automaticamente**.',
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
          title: l10n?.tutorialChordsStep6Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialChordsStep6Message ??
              'Sempre que quiser rever este guia ou tirar dúvidas sobre o uso do Leitor de Cifras, toque neste **ícone (i)**!',
        ),
      ),
    ),
  ];
}
