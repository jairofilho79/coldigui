import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela do Leitor de Partituras / PDF ([PdfReaderScreen]).
List<SpotlightGuideStep> buildReaderTutorialSteps(BuildContext context) {
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
          title: 'Ajuste de Tela',
          message:
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
          title: 'Modo Tela Cheia',
          message:
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
          title: 'Indicador de Páginas',
          message:
              'Exibe a **página atual** e o **total de páginas**. Toque para saltar de página ou **segure o toque** para voltar direto à **primeira página**!',
        ),
      ),
    ),

    // 4. Virada de Páginas
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
          title: 'Virada de Páginas',
          message:
              'Toque nas **laterais da tela**, use as **setas do teclado** ou conecte um **pedal Bluetooth** para avançar e voltar páginas sem tirar as mãos do instrumento.',
        ),
      ),
    ),

    // 5. Ajuda & Tutoriais
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
              'Toque no ícone **(i)** sempre que tiver dúvidas sobre como utilizar as ferramentas do leitor!',
        ),
      ),
    ),
  ];
}
