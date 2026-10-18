import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Armazenamento Offline ([OfflineSettingsScreen]).
List<SpotlightGuideStep> buildOfflineTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Status e Uso de Disco
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'offline-status-lines',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialOfflineStep1Title ?? 'Status e Uso de Disco',
          message:
              l10n?.tutorialOfflineStep1Message ??
              'Acompanhe o total de louvores no **catálogo local**, a data da **última sincronização** e o **espaço ocupado e livre** no aparelho. Toque em **Atualizar** para recalcular os dados.',
        ),
      ),
    ),

    // 2. Pesquisa de Materiais
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'offline-search-bar',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialOfflineStep2Title ?? 'Pesquisa de Materiais',
          message:
              l10n?.tutorialOfflineStep2Message ??
              'Use o campo de busca para encontrar rapidamente tipos específicos de partituras ou cifras (ex: **violão**, **coletânea**, **coral**) e ative **Filtrar** para exibir apenas os resultados correspondentes.',
        ),
      ),
    ),

    // 3. Seleção de Formatos
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'offline-kinds-selection',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialOfflineStep3Title ?? 'Seleção de Formatos',
          message:
              l10n?.tutorialOfflineStep3Message ??
              'Selecione os **tipos de materiais** que você deseja manter disponíveis offline. Em cada item é possível alternar individualmente entre **partitura (PDF)**, **cifra** e **áudio**.',
        ),
      ),
    ),

    // 4. Baixar e Gerenciar Espaço
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'offline-download-actions',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 14,
          padding: const EdgeInsets.all(8),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialOfflineStep4Title ?? 'Baixar e Gerenciar Espaço',
          message:
              l10n?.tutorialOfflineStep4Message ??
              'Toque em **Baixar selecionados** para salvar os arquivos no aparelho para uso sem internet. Quando precisar liberar espaço em disco, toque em **Remover downloads**.',
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
          title: l10n?.tutorialOfflineStep5Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialOfflineStep5Message ??
              'Sempre que tiver dúvidas sobre o armazenamento offline, toque neste **ícone (i)** para rever este tutorial passo a passo!',
        ),
      ),
    ),
  ];
}
