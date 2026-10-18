import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela do Leitor de Partituras / PDF ([PdfReaderScreen]).
List<SpotlightGuideStep> buildReaderTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Ajuste de Tela (Largura vs. Página)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'reader-fit-mode-button',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialReaderStep1Title ?? 'Ajuste de Tela',
          message:
              l10n?.tutorialReaderStep1Message ??
              'Alterne entre ajustar à **largura da tela** (ótimo para ampliar a partitura) ou à **página inteira**. Você também pode pressionar a tecla **Z**.',
        ),
      ),
    ),

    // 2. Modo Tela Cheia
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'reader-fullscreen-button',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialReaderStep2Title ?? 'Modo Tela Cheia',
          message:
              l10n?.tutorialReaderStep2Message ??
              'Toque para ocultar todas as barras e **focar na partitura** durante o ensaio ou culto. Use a tecla **F** para entrar ou **Esc** para sair.',
        ),
      ),
    ),

    // 3. Indicador de Páginas
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'reader-page-indicator',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialReaderStep3Title ?? 'Indicador de Páginas',
          message:
              l10n?.tutorialReaderStep3Message ??
              'Exibe a **página atual** e o **total de páginas**. Toque para saltar de página ou **segure o toque** para voltar direto à **primeira página**!',
        ),
      ),
    ),

    // 4. Toque nas Bordas (Laterais)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'reader-pdf-view',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 8,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialReaderStep4Title ?? 'Toque nas Bordas (Laterais)',
          message:
              l10n?.tutorialReaderStep4Message ??
              'Toque no **quinto lateral esquerdo** para voltar e no **quinto lateral direito** para avançar páginas instantaneamente, sem precisar arrastar a partitura.',
        ),
      ),
    ),

    // 5. Pedais Bluetooth & Teclado
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'reader-pdf-view',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 8,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialReaderStep5Title ?? 'Pedais Bluetooth & Teclado',
          message:
              l10n?.tutorialReaderStep5Message ??
              'Conecte qualquer **pedal virador de página Bluetooth** (AirTurn, PageFlip, Donner via PageUp/Down ou Setas) para avançar e trocar de louvor **sem tirar as mãos do instrumento**.',
        ),
      ),
    ),

    // 6. Ajuda & Tutoriais
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
          title: l10n?.tutorialReaderStep6Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialReaderStep6Message ??
              'Toque no ícone **(i)** sempre que tiver dúvidas sobre como utilizar as ferramentas do leitor!',
        ),
      ),
    ),
  ];
}
