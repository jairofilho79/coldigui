import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial do Seletor de Formatos ([MaterialSheet]).
List<SpotlightGuideStep> buildMaterialSheetTutorialSteps(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Abas de Formatos
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'material-sheet-tabs',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialMaterialSheetStep1Title ?? 'Formatos Disponíveis',
          message:
              l10n?.tutorialMaterialSheetStep1Message ??
              'Alterne entre **Partituras**, **Cifras**, **Gestos CIAs**, **Áudios** e vídeos do **YouTube** para escolher o formato ideal para o culto ou ensaio.',
        ),
      ),
    ),

    // 2. Adicionar ao Repertório
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'material-sheet-add-playlist',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialMaterialSheetStep2Title ?? 'Adicionar ao Repertório',
          message:
              l10n?.tutorialMaterialSheetStep2Message ??
              'Toque no botão **+** para incluir este arranjo diretamente na sua lista ativa do **Carrossel de culto** ou em uma de suas **Playlists**.',
        ),
      ),
    ),

    // 3. Metadados e Letra
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'material-sheet-meta',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialMaterialSheetStep3Title ?? 'Metadados e Letra',
          message:
              l10n?.tutorialMaterialSheetStep3Message ??
              'Consulte a **tonalidade original**, **ritmo**, **categorias de culto** e confira a prévia da letra do louvor.',
        ),
      ),
    ),

    // 4. Versões Relacionadas
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'material-sheet-related',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialMaterialSheetStep4Title ?? 'Versões Relacionadas',
          message:
              l10n?.tutorialMaterialSheetStep4Message ??
              'Selecione rapidamente **arranjos alternativos**, versões com outras tonalidades ou hinos correlacionados ao louvor selecionado.',
        ),
      ),
    ),

    // 5. Sugerir Melhoria
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'material-sheet-contribute',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialMaterialSheetStep5Title ?? 'Sugerir Melhoria',
          message:
              l10n?.tutorialMaterialSheetStep5Message ??
              'Encontrou alguma divergência na cifra, letra ou partitura? Toque aqui para enviar uma **sugestão de correção** aos curadores.',
        ),
      ),
    ),

    // 6. Ajuda deste Seletor
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'material-sheet-info',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialMaterialSheetStep6Title ?? 'Ajuda deste Seletor',
          message:
              l10n?.tutorialMaterialSheetStep6Message ??
              'Toque neste ícone sempre que precisar de orientação sobre como **escolher materiais** e **organizar o repertório**.',
        ),
      ),
    ),
  ];
}
