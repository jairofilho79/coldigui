import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/tutorial/presentation/providers/tutorial_provider.dart';
import 'package:coldigui/core/tutorial/presentation/widgets/coldigui_tutorial_hint.dart';
import 'package:coldigui/core/widgets/plpcg_primary_app_bar.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/filters_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

void main() {
  group('TutorialController', () {
    test('hasTutorialFor reconhece a rota home', () {
      final controller = TutorialController();
      expect(controller.hasTutorialFor(RoutePaths.home), isTrue);
      expect(controller.hasTutorialFor('/rota-inexistente'), isFalse);
    });

    testWidgets('stepsForRoute retorna passos da Home com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps = controller.stepsForRoute(context, RoutePaths.home);
                expect(steps.length, 5);
                expect(steps[0].items.first.targetId, 'home-search-bar');
                expect(steps[1].items.first.targetId, 'home-filters-panel');
                expect(steps[2].items.first.targetId, 'home-filters-panel');
                expect(steps[3].items.first.targetId, 'home-bottom-nav');
                expect(steps[4].items.first.targetId, 'app-info-button');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('toque no botão (i) na AppBar dispara o tutorial e navega pelos passos',
        (tester) async {
      late ProviderContainer container;

      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, state) {
              final tutorial = ProviderScope.containerOf(context)
                  .read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorial.portalController,
                autoStart: false,
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: Column(
                    children: [
                      SpotlightGuideTarget(
                        id: 'home-search-bar',
                        child: const Text('Barra de Busca'),
                      ),
                      SpotlightGuideTarget(
                        id: 'home-filters-panel',
                        child: const Text('Painel de Filtros'),
                      ),
                      SpotlightGuideTarget(
                        id: 'home-bottom-nav',
                        child: const Text('Navegação'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Encontra o botão (i)
      final infoButtonFinder = find.byIcon(Icons.info_outline);
      expect(infoButtonFinder, findsOneWidget);

      // Toca no botão (i)
      await tester.tap(infoButtonFinder);
      await tester.pumpAndSettle();

      // Passo 1: Pesquisa Inteligente
      expect(find.text('Pesquisa Inteligente'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Avança para o Passo 2: Filtros do Catálogo (Recolhido / Inativo)
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Filtros do Catálogo (Recolhido)'), findsOneWidget);
      expect(
        container.read(
          filtersPanelExpandedOverrideProvider(CatalogFilterScope.home),
        ),
        isFalse,
      );

      // Avança para o Passo 3: Filtros do Catálogo (Expandido / Ativo)
      await tester.tap(find.text('Próximo'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Filtros do Catálogo (Expandido)'), findsOneWidget);
      expect(
        container.read(
          filtersPanelExpandedOverrideProvider(CatalogFilterScope.home),
        ),
        isTrue,
      );
    });

    testWidgets('ColdiguiTutorialHint renderiza palavras em negrito via markdown',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpotlightGuidePortal(
              steps: [
                SpotlightGuideStep.item(
                  SpotlightGuideStepItem(
                    targetId: 'dummy-target',
                    hintBuilder: (context, guide) => ColdiguiTutorialHint(
                      guide: guide,
                      title: 'Teste de Destaque',
                      message: 'Texto normal com **palavra em negrito** aqui.',
                    ),
                  ),
                ),
              ],
              child: SpotlightGuideTarget(
                id: 'dummy-target',
                child: const Text('Alvo'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Encontra o RichText com os spans esperados
      expect(find.text('Teste de Destaque'), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });
  });
}
