import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela da Biblioteca ([LibraryScreen]).
List<SpotlightGuideStep> buildLibraryTutorialSteps(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Painel de Filtros do Catálogo
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'library-filters-panel',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        onReveal: (context) async {
          try {
            Scrollable.ensureVisible(
              context.context,
              duration: const Duration(milliseconds: 150),
            );
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLibraryStep1Title ?? 'Filtros do Catálogo',
          message:
              l10n?.tutorialLibraryStep1Message ??
              'Refine a biblioteca completa por **tom musical**, **ritmo**, **categorias/tags** ou **tipo de material** (partituras, cifras, áudio). Toque no cabeçalho para **expandir ou recolher** os filtros.',
        ),
      ),
    ),

    // 2. Ordenação do Catálogo
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'library-sort-selector',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        onReveal: (context) async {
          try {
            Scrollable.ensureVisible(
              context.context,
              duration: const Duration(milliseconds: 150),
            );
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLibraryStep2Title ?? 'Ordenação do Acervo',
          message:
              l10n?.tutorialLibraryStep2Message ??
              'Alterne rapidamente a ordem dos louvores entre **"Por número"** (código oficial no hinário) ou **"Por nome"** (ordem alfabética dos títulos).',
        ),
      ),
    ),

    // 3. Paginação e Quantidade por Página
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'library-pagination-controls',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        onReveal: (context) async {
          try {
            Scrollable.ensureVisible(
              context.context,
              duration: const Duration(milliseconds: 150),
            );
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 10,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLibraryStep3Title ?? 'Paginação e Exibição',
          message:
              l10n?.tutorialLibraryStep3Message ??
              'Consulte o **total de louvores** encontrados, selecione a **quantidade de itens por página** (10, 20, 50...) e use as **setas de navegação** para folhear o catálogo.',
        ),
      ),
    ),

    // 4. Primeiro Card de Louvor (quando houver itens)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'library-first-card',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        onReveal: (context) async {
          try {
            Scrollable.ensureVisible(
              context.context,
              duration: const Duration(milliseconds: 150),
            );
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialLibraryStep4Title ?? 'Cards de Louvor',
          message:
              l10n?.tutorialLibraryStep4Message ??
              'Cada card apresenta o número, título e detalhes do louvor. Toque nele para acessar diretamente suas **partituras**, **cifras**, **áudios** e **informações completas**.',
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
          title: l10n?.tutorialLibraryStep5Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialLibraryStep5Message ??
              'Sempre que tiver dúvidas sobre como navegar ou usar a Biblioteca, toque neste **ícone (i)** para rever este guia passo a passo!',
        ),
      ),
    ),
  ];
}
