import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial do Leitor de Gestos CIAs ([GestureReaderScreen]).
List<SpotlightGuideStep> buildGesturesTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Tamanho da Fonte
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'gestures-font-size-controls',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialGesturesStep1Title ?? 'Tamanho da Letra',
          message:
              l10n?.tutorialGesturesStep1Message ??
              'Aumente ou diminua o **tamanho do texto** dos louvores para uma leitura mais confortável durante o ensaio ou culto.',
        ),
      ),
    ),

    // 2. Rolagem Automática (Autoscroll)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'gestures-autoscroll-controls',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialGesturesStep2Title ?? 'Rolagem Automática',
          message:
              l10n?.tutorialGesturesStep2Message ??
              'Ative a **rolagem automática** (tecla **S**) para acompanhar os gestos sem tocar na tela. Ajuste a **velocidade** no velocímetro ou pelas teclas **[** e **]**.',
        ),
      ),
    ),

    // 3. Modo Linear vs. Estruturado
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'gestures-view-mode-button',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialGesturesStep3Title ?? 'Modo Linear vs. Estruturado',
          message:
              l10n?.tutorialGesturesStep3Message ??
              'Alterne entre a exibição **estruturada** (agrupada por estrofes e refrões) e a leitura **linear** (sequência contínua com todas as repetições completas).',
        ),
      ),
    ),

    // 4. Tema e Tela Cheia
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'gestures-mode-controls',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialGesturesStep4Title ?? 'Tema e Tela Cheia',
          message:
              l10n?.tutorialGesturesStep4Message ??
              'Alterne entre o **modo claro e escuro** para melhor visibilidade, e use o modo **tela cheia** (tecla **F**) para ocultar barras e focar na execução dos gestos.',
        ),
      ),
    ),

    // 5. Cartões de Gestos
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'gestures-content-view',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialGesturesStep5Title ?? 'Cartões de Gestos',
          message:
              l10n?.tutorialGesturesStep5Message ??
              'Os gestos aparecem sincronizados com as palavras correspondentes. Toque em qualquer **cartão de gesto** para abrir a **visão em foco** com imagem ampliada e descrição detalhada.',
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
          title: l10n?.tutorialGesturesStep6Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialGesturesStep6Message ??
              'Sempre que tiver dúvidas sobre como usar o leitor de gestos, toque neste **ícone (i)** para rever este tutorial passo a passo!',
        ),
      ),
    ),
  ];
}
