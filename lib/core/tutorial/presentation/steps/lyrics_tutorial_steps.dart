import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial do Leitor de Letras ([LyricsReaderScreen]).
List<SpotlightGuideStep> buildLyricsTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Tamanho da Letra
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'lyrics-font-size-controls',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLyricsStep1Title ?? 'Tamanho da Letra',
          message:
              l10n?.tutorialLyricsStep1Message ??
              'Aumente ou diminua o **tamanho da fonte** da letra para uma leitura mais confortável durante o ensaio ou culto. Também é possível usar **Ctrl + ↑ / ↓** (ou **Cmd + ↑ / ↓**).',
        ),
      ),
    ),

    // 2. Rolagem Automática (Autoscroll)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'lyrics-autoscroll-controls',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLyricsStep2Title ?? 'Rolagem Automática',
          message:
              l10n?.tutorialLyricsStep2Message ??
              'Ative a **rolagem automática** (tecla **S**) para ler a letra sem tocar na tela. Toque no **velocímetro** para ajustar a velocidade (ou pelas teclas **[** e **]**).',
        ),
      ),
    ),

    // 3. Modo Tela Cheia
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'lyrics-fullscreen-button',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLyricsStep3Title ?? 'Modo Tela Cheia',
          message:
              l10n?.tutorialLyricsStep3Message ??
              'Toque no botão de **tela cheia** (ou tecla **F**) para ocultar todas as barras e focar inteiramente na leitura da letra.',
        ),
      ),
    ),

    // 4. Leitura e Seleção de Texto
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'lyrics-content-view',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLyricsStep4Title ?? 'Leitura e Seleção de Texto',
          message:
              l10n?.tutorialLyricsStep4Message ??
              'A letra do louvor fica disponível **completamente offline**. O texto é selecionável para copiar trechos e a rolagem é pausada suavemente ao tocar na tela.',
        ),
      ),
    ),

    // 5. Ícone de ajuda (i)
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
          title: l10n?.tutorialLyricsStep5Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialLyricsStep5Message ??
              'Sempre que tiver dúvidas sobre como usar o leitor de letras, toque neste **ícone (i)** para rever este tutorial passo a passo!',
        ),
      ),
    ),
  ];
}
