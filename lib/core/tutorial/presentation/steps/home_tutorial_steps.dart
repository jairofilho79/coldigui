import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../features/catalog/presentation/providers/catalog_filter_options_provider.dart';
import '../../../../features/catalog/presentation/providers/catalog_filters_provider.dart';
import '../../../../features/catalog/presentation/widgets/filters_panel.dart';
import '../widgets/coldigui_tutorial_hint.dart';


/// Passos do tutorial da tela inicial / Pesquisador ([HomeScreen]).
List<SpotlightGuideStep> buildHomeTutorialSteps(BuildContext context) {
  return [
    // 1. Barra de pesquisa
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-search-bar',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        onReveal: (context) async {
          final container = ProviderScope.containerOf(context.context);
          container
              .read(
                filtersPanelExpandedOverrideProvider(CatalogFilterScope.home)
                    .notifier,
              )
              .set(false);
          container
              .read(catalogFiltersProviderFor(CatalogFilterScope.home).notifier)
              .restoreTutorialFilters();
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 10,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Pesquisa Inteligente',
          message:
              'Digite o **número** do louvor, o **título** ou um **trecho da letra** para localizá-lo instantaneamente no catálogo.',
        ),
      ),
    ),

    // 2. Filtro Ativo
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-filter-chip-sample',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        onReveal: (context) async {
          final container = ProviderScope.containerOf(context.context);
          container
              .read(
                filtersPanelExpandedOverrideProvider(CatalogFilterScope.home)
                    .notifier,
              )
              .set(true);

          final options = container.read(catalogFilterOptionsProvider);
          final sampleTonality =
              options.tonalities.isNotEmpty ? options.tonalities.first : 'C';

          container
              .read(catalogFiltersProviderFor(CatalogFilterScope.home).notifier)
              .setTutorialFilters(
                CatalogFilterState(
                  tonalities: {sampleTonality},
                ),
              );

          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Filtros Ativos',
          message:
              'Quando **ativo**, o botão do filtro selecionado ganha **destaque dourado**. O cabeçalho exibe a contagem de **filtros ativos** e você pode tocar em **"Limpar filtros"** para desmarcar tudo.',
        ),
      ),
    ),

    // 3. Filtro Inativo
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-filter-chip-sample',
        placement: SpotlightGuidePlacement.verticalAuto,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        onReveal: (context) async {
          final container = ProviderScope.containerOf(context.context);
          container
              .read(
                filtersPanelExpandedOverrideProvider(CatalogFilterScope.home)
                    .notifier,
              )
              .set(true);
          container
              .read(catalogFiltersProviderFor(CatalogFilterScope.home).notifier)
              .setTutorialFilters(CatalogFilterState.empty);
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Filtros Inativos',
          message:
              'Com os filtros **inativos** (desmarcados), a busca abrange **todo o catálogo**. Toque em qualquer botão para **ativá-lo** ou recolha o painel para ganhar espaço.',
        ),
      ),
    ),

    // 4. Barra de navegação principal
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-bottom-nav',
        placement: SpotlightGuidePlacement.top,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        onReveal: (context) async {
          final container = ProviderScope.containerOf(context.context);
          container
              .read(
                filtersPanelExpandedOverrideProvider(CatalogFilterScope.home)
                    .notifier,
              )
              .set(false);
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 16,
          padding: const EdgeInsets.all(6),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Navegação Principal',
          message:
              'Alterne facilmente entre o **Pesquisador** de Louvores, suas **Listas** salvas e o seu **Perfil** de usuário.',
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
          title: 'Ajuda & Tutoriais',
          message:
              'Sempre que tiver dúvidas sobre como usar qualquer tela, toque neste **ícone (i)** para rever as explicações passo a passo!',
        ),
      ),
    ),
  ];
}
