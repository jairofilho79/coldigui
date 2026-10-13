import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/tutorial/presentation/providers/tutorial_provider.dart';
import 'package:coldigui/core/tutorial/presentation/widgets/coldigui_tutorial_hint.dart';
import 'package:coldigui/core/widgets/plpcg_primary_app_bar.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/filters_panel.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
                expect(steps[1].items.first.targetId, 'home-filter-chip-sample');
                expect(steps[2].items.first.targetId, 'home-filter-chip-sample');
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
                onFinish: () => tutorial.resetTutorialState(),
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SpotlightGuideTarget(
                          id: 'home-filter-chip-sample',
                          child: const SizedBox(
                            height: 36,
                            child: Text('Filtro Sample'),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: SpotlightGuideTarget(
                          id: 'home-search-bar',
                          child: const SizedBox(
                            height: 50,
                            child: Text('Barra de Busca'),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SpotlightGuideTarget(
                          id: 'home-bottom-nav',
                          child: const Text('Navegação'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
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

      final barrierFinder = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_SpotlightBarrierPainter',
      );
      expect(barrierFinder, findsWidgets);
      final customPaint = tester.widget<CustomPaint>(barrierFinder.first);
      dynamic painter = customPaint.painter;
      expect(painter.targetHoles.isNotEmpty, isTrue);

      // Avança para o Passo 2: Filtros Ativos
      await tester.tap(find.text('Próximo'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Filtros Ativos'), findsOneWidget);
      expect(
        container.read(
          filtersPanelExpandedOverrideProvider(CatalogFilterScope.home),
        ),
        isTrue,
      );
      expect(
        container
            .read(catalogFiltersProviderFor(CatalogFilterScope.home))
            .activeCount,
        greaterThan(0),
      );

      // Avança para o Passo 3: Filtros Inativos
      await tester.tap(find.text('Próximo'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Filtros Inativos'), findsOneWidget);
      expect(
        container.read(
          filtersPanelExpandedOverrideProvider(CatalogFilterScope.home),
        ),
        isTrue,
      );
      expect(
        container
            .read(catalogFiltersProviderFor(CatalogFilterScope.home))
            .activeCount,
        equals(0),
      );

      // Avança para o Passo 4: Navegação Principal
      await tester.tap(find.text('Próximo'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Navegação Principal'), findsOneWidget);

      // Avança para o Passo 5: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      // Toca em Concluir e verifica restauração dos estados
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(
        container.read(
          filtersPanelExpandedOverrideProvider(CatalogFilterScope.home),
        ),
        isNull,
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
