import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

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
        placement: SpotlightGuidePlacement.bottom,
        onReveal: (context) async {
          ProviderScope.containerOf(context.context)
              .read(
                filtersPanelExpandedOverrideProvider(CatalogFilterScope.home)
                    .notifier,
              )
              .set(false);
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        targetDecoration: const SpotlightGuideTargetDecoration(
          padding: EdgeInsets.all(4),
          shape: SpotlightGuideRoundedRectShape(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Pesquisa Inteligente',
          message:
              'Digite o **número** do louvor, o **título** ou um **trecho da letra** para localizá-lo instantaneamente no catálogo.',
        ),
      ),
    ),

    // 2. Painel de Filtros (Inativo / Recolhido)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-filters-panel',
        placement: SpotlightGuidePlacement.bottom,
        onReveal: (context) async {
          ProviderScope.containerOf(context.context)
              .read(
                filtersPanelExpandedOverrideProvider(CatalogFilterScope.home)
                    .notifier,
              )
              .set(false);
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        targetDecoration: const SpotlightGuideTargetDecoration(
          padding: EdgeInsets.all(4),
          shape: SpotlightGuideRoundedRectShape(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Filtros do Catálogo (Recolhido)',
          message:
              'Quando **inativo**, o painel fica **fechado** exibindo **"Toque para filtrar"** para economizar espaço e manter a visualização limpa.',
        ),
      ),
    ),

    // 3. Painel de Filtros (Ativo / Expandido)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-filters-panel',
        placement: SpotlightGuidePlacement.bottom,
        onReveal: (context) async {
          ProviderScope.containerOf(context.context)
              .read(
                filtersPanelExpandedOverrideProvider(CatalogFilterScope.home)
                    .notifier,
              )
              .set(true);
          // Aguarda o painel expandir para o holofote englobar todas as opções
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        targetDecoration: const SpotlightGuideTargetDecoration(
          padding: EdgeInsets.all(6),
          shape: SpotlightGuideRoundedRectShape(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: 'Filtros do Catálogo (Expandido)',
          message:
              'Ao **abrir**, você refina por **Tom musical**, **Ritmo**, **Coletâneas/Tags** e **Tipo de material** (**Partitura**, **Cifra** ou **Áudio**). Com filtros selecionados, o botão **"Limpar filtros"** surge para desmarcar tudo.',
        ),
      ),
    ),

    // 4. Barra de navegação principal
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'home-bottom-nav',
        placement: SpotlightGuidePlacement.top,
        onReveal: (context) async {
          ProviderScope.containerOf(context.context)
              .read(
                filtersPanelExpandedOverrideProvider(CatalogFilterScope.home)
                    .notifier,
              )
              .set(false);
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        targetDecoration: const SpotlightGuideTargetDecoration(
          padding: EdgeInsets.all(6),
          shape: SpotlightGuideRoundedRectShape(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
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
        targetDecoration: const SpotlightGuideTargetDecoration(
          padding: EdgeInsets.all(4),
          shape: SpotlightGuideRoundedRectShape(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
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
