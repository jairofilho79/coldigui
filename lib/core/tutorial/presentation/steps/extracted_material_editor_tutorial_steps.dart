import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial do editor de materiais extraídos ([ExtractedMaterialEditorScaffold]).
List<SpotlightGuideStep> buildExtractedMaterialEditorTutorialSteps(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Barra de Ferramentas e Atalhos
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'extracted-editor-toolbar',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialExtractedMaterialEditorStep1Title ?? 'Barra de Ferramentas & Atalhos',
          message:
              l10n?.tutorialExtractedMaterialEditorStep1Message ??
              'Utilize os atalhos rápidos para **adicionar versos**, **remover linhas**, **inserir acordes ou anotações** e restaurar o texto original.',
        ),
      ),
    ),

    // 2. Área de Edição do Material
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'extracted-editor-workspace',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 14,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialExtractedMaterialEditorStep2Title ?? 'Área de Edição',
          message:
              l10n?.tutorialExtractedMaterialEditorStep2Message ??
              'Edite o conteúdo diretamente. Na cifra, use a sintaxe **[Acorde]** imediatamente antes da sílaba para sincronizar a posição com a letra.',
        ),
      ),
    ),

    // 3. Seletor de Gestos CIAs (se houver)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'extracted-gesture-picker',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialExtractedMaterialEditorStep3Title ?? 'Seletor de Gestos CIAs',
          message:
              l10n?.tutorialExtractedMaterialEditorStep3Message ??
              'Toque em **Trocar Gesto** para abrir o dicionário oficial e vincular o movimento e a frase disparadora correspondente.',
        ),
      ),
    ),

    // 4. Pré-visualização em Tempo Real
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'extracted-editor-preview',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialExtractedMaterialEditorStep4Title ?? 'Pré-visualização ao Vivo',
          message:
              l10n?.tutorialExtractedMaterialEditorStep4Message ??
              'Acompanhe as mudanças **em tempo real** com a renderização idêntica à que os usuários verão no leitor de louvores.',
        ),
      ),
    ),

    // 5. Botão Enviar Proposta
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'extracted-editor-submit',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 24,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialExtractedMaterialEditorStep5Title ?? 'Submissão da Proposta',
          message:
              l10n?.tutorialExtractedMaterialEditorStep5Message ??
              'Adicione observações se desejar e toque em **Enviar** para disponibilizar sua sugestão para revisão pela comunidade.',
        ),
      ),
    ),

    // 6. Botão de Ajuda
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
          title: l10n?.tutorialExtractedMaterialEditorStep6Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialExtractedMaterialEditorStep6Message ??
              'Toque neste ícone a qualquer momento para rever este **guia passo a passo** do editor de materiais.',
        ),
      ),
    ),
  ];
}
