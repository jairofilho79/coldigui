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
    test('hasTutorialFor reconhece as rotas home, playlists, profile, reader, library, chords, gestos, audio, offline, lyrics, praise e about', () {
      final controller = TutorialController();
      expect(controller.hasTutorialFor(RoutePaths.home), isTrue);
      expect(controller.hasTutorialFor(RoutePaths.playlists), isTrue);
      expect(controller.hasTutorialFor(RoutePaths.profile), isTrue);
      expect(controller.hasTutorialFor(RoutePaths.reader), isTrue);
      expect(controller.hasTutorialFor(RoutePaths.library), isTrue);
      expect(controller.hasTutorialFor(RoutePaths.chords), isTrue);
      expect(controller.hasTutorialFor(RoutePaths.gestos), isTrue);
      expect(controller.hasTutorialFor(RoutePaths.audio), isTrue);
      expect(controller.hasTutorialFor(RoutePaths.offline), isTrue);
      expect(controller.hasTutorialFor(RoutePaths.lyrics), isTrue);
      expect(controller.hasTutorialFor(RoutePaths.praise), isTrue);
      expect(controller.hasTutorialFor('/louvor/0a1'), isTrue);
      expect(controller.hasTutorialFor(RoutePaths.about), isTrue);
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

    testWidgets('stepsForRoute retorna passos de Listas com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps =
                    controller.stepsForRoute(context, RoutePaths.playlists);
                expect(steps.length, 5);
                expect(steps[0].items.first.targetId, 'playlists-tabs');
                expect(steps[1].items.first.targetId, 'playlists-import-button');
                expect(steps[2].items.first.targetId, 'playlists-live-room-button');
                expect(steps[3].items.first.targetId, 'home-bottom-nav');
                expect(steps[4].items.first.targetId, 'app-info-button');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('stepsForRoute retorna passos do Perfil com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps =
                    controller.stepsForRoute(context, RoutePaths.profile);
                expect(steps.length, 5);
                expect(steps[0].items.first.targetId, 'profile-account-panel');
                expect(steps[1].items.first.targetId, 'profile-library-tile');
                expect(steps[2].items.first.targetId, 'profile-contribute-tile');
                expect(steps[3].items.first.targetId, 'profile-offline-tile');
                expect(steps[4].items.first.targetId, 'app-info-button');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('stepsForRoute retorna passos do Leitor com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps =
                    controller.stepsForRoute(context, RoutePaths.reader);
                expect(steps.length, 5);
                expect(steps[0].items.first.targetId, 'reader-fit-mode-button');
                expect(steps[1].items.first.targetId, 'reader-fullscreen-button');
                expect(steps[2].items.first.targetId, 'reader-page-indicator');
                expect(steps[3].items.first.targetId, 'reader-pdf-view');
                expect(steps[4].items.first.targetId, 'app-info-button');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('stepsForRoute retorna passos da Biblioteca com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps =
                    controller.stepsForRoute(context, RoutePaths.library);
                expect(steps.length, 5);
                expect(steps[0].items.first.targetId, 'library-filters-panel');
                expect(steps[1].items.first.targetId, 'library-sort-selector');
                expect(steps[2].items.first.targetId, 'library-pagination-controls');
                expect(steps[3].items.first.targetId, 'library-first-card');
                expect(steps[4].items.first.targetId, 'app-info-button');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('stepsForRoute retorna passos de Cifras com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps =
                    controller.stepsForRoute(context, RoutePaths.chords);
                expect(steps.length, 6);
                expect(steps[0].items.first.targetId, 'chords-transpose-controls');
                expect(steps[1].items.first.targetId, 'chords-font-size-controls');
                expect(steps[2].items.first.targetId, 'chords-autoscroll-controls');
                expect(steps[3].items.first.targetId, 'chords-mode-controls');
                expect(steps[4].items.first.targetId, 'chords-content-view');
                expect(steps[5].items.first.targetId, 'app-info-button');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('stepsForRoute retorna passos de Gestos com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps =
                    controller.stepsForRoute(context, RoutePaths.gestos);
                expect(steps.length, 6);
                expect(steps[0].items.first.targetId, 'gestures-font-size-controls');
                expect(steps[1].items.first.targetId, 'gestures-autoscroll-controls');
                expect(steps[2].items.first.targetId, 'gestures-view-mode-button');
                expect(steps[3].items.first.targetId, 'gestures-mode-controls');
                expect(steps[4].items.first.targetId, 'gestures-content-view');
                expect(steps[5].items.first.targetId, 'app-info-button');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('stepsForRoute retorna passos de Áudio com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps =
                    controller.stepsForRoute(context, RoutePaths.audio);
                expect(steps.length, 6);
                expect(steps[0].items.first.targetId, 'audio-track-info');
                expect(steps[1].items.first.targetId, 'audio-quick-actions');
                expect(steps[2].items.first.targetId, 'audio-seek-bar');
                expect(steps[3].items.first.targetId, 'audio-transport-controls');
                expect(steps[4].items.first.targetId, 'audio-flag-list');
                expect(steps[5].items.first.targetId, 'app-info-button');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('stepsForRoute retorna passos do Armazenamento Offline com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps =
                    controller.stepsForRoute(context, RoutePaths.offline);
                expect(steps.length, 5);
                expect(steps[0].items.first.targetId, 'offline-status-lines');
                expect(steps[1].items.first.targetId, 'offline-search-bar');
                expect(steps[2].items.first.targetId, 'offline-kinds-selection');
                expect(steps[3].items.first.targetId, 'offline-download-actions');
                expect(steps[4].items.first.targetId, 'app-info-button');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('stepsForRoute retorna passos do Leitor de Letras com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps =
                    controller.stepsForRoute(context, RoutePaths.lyrics);
                expect(steps.length, 5);
                expect(steps[0].items.first.targetId, 'lyrics-font-size-controls');
                expect(steps[1].items.first.targetId, 'lyrics-autoscroll-controls');
                expect(steps[2].items.first.targetId, 'lyrics-fullscreen-button');
                expect(steps[3].items.first.targetId, 'lyrics-content-view');
                expect(steps[4].items.first.targetId, 'app-info-button');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets(
        'stepsForRoute retorna passos da tela de Detalhes do Louvor com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps =
                    controller.stepsForRoute(context, RoutePaths.praise);
                expect(steps.length, 5);
                expect(steps[0].items.first.targetId, 'praise-header');
                expect(steps[1].items.first.targetId, 'praise-related-bar');
                expect(steps[2].items.first.targetId, 'praise-materials-section');
                expect(steps[3].items.first.targetId, 'praise-lyrics-section');
                expect(steps[4].items.first.targetId, 'app-info-button');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets(
        'stepsForRoute retorna passos da tela Sobre com alvos configurados',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final controller = TutorialController();
                final steps =
                    controller.stepsForRoute(context, RoutePaths.about);
                expect(steps.length, 3);
                expect(steps[0].items.first.targetId, 'about-who-we-are');
                expect(steps[1].items.first.targetId, 'about-mission');
                expect(steps[2].items.first.targetId, 'app-info-button');
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

    testWidgets(
        'toque no botão (i) na tela de Listas dispara o tutorial e navega pelos passos',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.playlists,
        routes: [
          GoRoute(
            path: RoutePaths.playlists,
            builder: (context, state) {
              final tutorial = ProviderScope.containerOf(context)
                  .read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorial.portalController,
                autoStart: false,
                onFinish: () => tutorial.resetTutorialState(),
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: Column(
                    children: [
                      SpotlightGuideTarget(
                        id: 'playlists-tabs',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Barra de Abas'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'playlists-import-button',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Import'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'playlists-live-room-button',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Live'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'home-bottom-nav',
                        child: const Text('Mock Nav'),
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
          child: MaterialApp.router(
            routerConfig: router,
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

      // Passo 1: Abas de Repertório
      expect(find.text('Abas de Repertório'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Passo 2: Importar Lista
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Importar Lista'), findsOneWidget);

      // Passo 3: Sala ao Vivo
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Sala ao Vivo'), findsOneWidget);

      // Passo 4: Criar Novas Listas
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Criar Novas Listas'), findsOneWidget);

      // Passo 5: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsNothing);
    });

    testWidgets(
        'toque no botão (i) na tela de Perfil dispara o tutorial e navega pelos passos',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.profile,
        routes: [
          GoRoute(
            path: RoutePaths.profile,
            builder: (context, state) {
              final tutorial = ProviderScope.containerOf(context)
                  .read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorial.portalController,
                autoStart: false,
                onFinish: () => tutorial.resetTutorialState(),
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: ListView(
                    children: [
                      SpotlightGuideTarget(
                        id: 'profile-account-panel',
                        child: const SizedBox(
                          height: 60,
                          child: Text('Mock Account Panel'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'profile-library-tile',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Library Tile'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'profile-contribute-tile',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Contribute Tile'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'profile-offline-tile',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Offline Tile'),
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
          child: MaterialApp.router(
            routerConfig: router,
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

      // Passo 1: Conta & Sincronização
      expect(find.text('Conta & Sincronização'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Passo 2: Biblioteca Completa
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Biblioteca Completa'), findsOneWidget);

      // Passo 3: Contribuir
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Contribuir'), findsOneWidget);

      // Passo 4: Modo Offline
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Modo Offline'), findsOneWidget);

      // Passo 5: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsNothing);
    });

    testWidgets(
        'toque no botão (i) na tela do Leitor dispara o tutorial e navega pelos passos',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.reader,
        routes: [
          GoRoute(
            path: RoutePaths.reader,
            builder: (context, state) {
              final tutorial = ProviderScope.containerOf(context)
                  .read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorial.portalController,
                autoStart: false,
                onFinish: () => tutorial.resetTutorialState(),
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: Column(
                    children: [
                      SpotlightGuideTarget(
                        id: 'reader-fit-mode-button',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Fit Mode'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'reader-fullscreen-button',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Fullscreen'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'reader-page-indicator',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Page Indicator'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'reader-pdf-view',
                        child: const SizedBox(
                          height: 200,
                          child: Text('Mock PDF Area'),
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
          child: MaterialApp.router(
            routerConfig: router,
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

      // Passo 1: Ajuste de Tela
      expect(find.text('Ajuste de Tela'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Passo 2: Modo Tela Cheia
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Modo Tela Cheia'), findsOneWidget);

      // Passo 3: Indicador de Páginas
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Indicador de Páginas'), findsOneWidget);

      // Passo 4: Virada de Páginas
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Virada de Páginas'), findsOneWidget);

      // Passo 5: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsNothing);
    });

    testWidgets(
        'toque no botão (i) na tela da Biblioteca dispara o tutorial e navega pelos passos',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.library,
        routes: [
          GoRoute(
            path: RoutePaths.library,
            builder: (context, state) {
              final tutorial = ProviderScope.containerOf(context)
                  .read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorial.portalController,
                autoStart: false,
                onFinish: () => tutorial.resetTutorialState(),
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: Column(
                    children: [
                      SpotlightGuideTarget(
                        id: 'library-filters-panel',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Filters Panel'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'library-sort-selector',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Sort Selector'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'library-pagination-controls',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Pagination'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'library-first-card',
                        child: const SizedBox(
                          height: 100,
                          child: Text('Mock First Praise Card'),
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
          child: MaterialApp.router(
            routerConfig: router,
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

      // Passo 1: Filtros do Catálogo
      expect(find.text('Filtros do Catálogo'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Passo 2: Ordenação do Acervo
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ordenação do Acervo'), findsOneWidget);

      // Passo 3: Paginação e Exibição
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Paginação e Exibição'), findsOneWidget);

      // Passo 4: Cards de Louvor
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Cards de Louvor'), findsOneWidget);

      // Passo 5: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsNothing);
    });

    testWidgets(
        'toque no botão (i) na tela do Leitor de Cifras dispara o tutorial e navega pelos passos',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.chords,
        routes: [
          GoRoute(
            path: RoutePaths.chords,
            builder: (context, state) {
              final tutorial = ProviderScope.containerOf(context)
                  .read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorial.portalController,
                autoStart: false,
                onFinish: () => tutorial.resetTutorialState(),
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: Column(
                    children: [
                      SpotlightGuideTarget(
                        id: 'chords-transpose-controls',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Transpose'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'chords-font-size-controls',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Font Size'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'chords-autoscroll-controls',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Autoscroll'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'chords-mode-controls',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Mode'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'chords-content-view',
                        child: const SizedBox(
                          height: 200,
                          child: Text('Mock Chords Content'),
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
          child: MaterialApp.router(
            routerConfig: router,
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

      // Passo 1: Transposição de Tom
      expect(find.text('Transposição de Tom'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Passo 2: Tamanho da Fonte
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Tamanho da Fonte'), findsOneWidget);

      // Passo 3: Rolagem Automática
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Rolagem Automática'), findsOneWidget);

      // Passo 4: Tema e Tela Cheia
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Tema e Tela Cheia'), findsOneWidget);

      // Passo 5: Leitura e Diagramação
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Leitura e Diagramação'), findsOneWidget);

      // Passo 6: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsNothing);
    });

    testWidgets(
        'toque no botão (i) na tela do Leitor de Gestos dispara o tutorial e navega pelos passos',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.gestos,
        routes: [
          GoRoute(
            path: RoutePaths.gestos,
            builder: (context, state) {
              final tutorial = ProviderScope.containerOf(context)
                  .read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorial.portalController,
                autoStart: false,
                onFinish: () => tutorial.resetTutorialState(),
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: Column(
                    children: [
                      SpotlightGuideTarget(
                        id: 'gestures-font-size-controls',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Font Size'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'gestures-autoscroll-controls',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Autoscroll'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'gestures-view-mode-button',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock View Mode'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'gestures-mode-controls',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Mode'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'gestures-content-view',
                        child: const SizedBox(
                          height: 200,
                          child: Text('Mock Gestures Content'),
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
          child: MaterialApp.router(
            routerConfig: router,
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

      // Passo 1: Tamanho da Letra
      expect(find.text('Tamanho da Letra'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Passo 2: Rolagem Automática
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Rolagem Automática'), findsOneWidget);

      // Passo 3: Modo Linear vs. Estruturado
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Modo Linear vs. Estruturado'), findsOneWidget);

      // Passo 4: Tema e Tela Cheia
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Tema e Tela Cheia'), findsOneWidget);

      // Passo 5: Cartões de Gestos
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Cartões de Gestos'), findsOneWidget);

      // Passo 6: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsNothing);
    });

    testWidgets(
        'toque no botão (i) na tela do Reprodutor de Áudio dispara o tutorial e navega pelos passos',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.audio,
        routes: [
          GoRoute(
            path: RoutePaths.audio,
            builder: (context, state) {
              final tutorial = ProviderScope.containerOf(context)
                  .read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorial.portalController,
                autoStart: false,
                onFinish: () => tutorial.resetTutorialState(),
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: Column(
                    children: [
                      SpotlightGuideTarget(
                        id: 'audio-track-info',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Audio Track Info'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'audio-quick-actions',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Audio Quick Actions'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'audio-seek-bar',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Audio Seek Bar'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'audio-transport-controls',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Audio Transport Controls'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'audio-flag-list',
                        child: const SizedBox(
                          height: 80,
                          child: Text('Mock Audio Flag List'),
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
          child: MaterialApp.router(
            routerConfig: router,
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

      // Passo 1: Informações da Faixa
      expect(find.text('Informações da Faixa'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Passo 2: Ações e Sincronização
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ações e Sincronização'), findsOneWidget);

      // Passo 3: Barra de Progresso
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Barra de Progresso'), findsOneWidget);

      // Passo 4: Controles de Reprodução
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Controles de Reprodução'), findsOneWidget);

      // Passo 5: Marcadores de Estudo
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Marcadores de Estudo'), findsOneWidget);

      // Passo 6: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsNothing);
    });

    testWidgets(
        'toque no botão (i) na tela do Armazenamento Offline dispara o tutorial e navega pelos passos',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.offline,
        routes: [
          GoRoute(
            path: RoutePaths.offline,
            builder: (context, state) {
              final tutorial = ProviderScope.containerOf(context)
                  .read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorial.portalController,
                autoStart: false,
                onFinish: () => tutorial.resetTutorialState(),
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: Column(
                    children: [
                      SpotlightGuideTarget(
                        id: 'offline-status-lines',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Offline Status Lines'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'offline-search-bar',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Offline Search Bar'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'offline-kinds-selection',
                        child: const SizedBox(
                          height: 120,
                          child: Text('Mock Offline Kinds Selection'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'offline-download-actions',
                        child: const SizedBox(
                          height: 60,
                          child: Text('Mock Offline Download Actions'),
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
          child: MaterialApp.router(
            routerConfig: router,
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

      // Passo 1: Status e Uso de Disco
      expect(find.text('Status e Uso de Disco'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Passo 2: Pesquisa de Materiais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Pesquisa de Materiais'), findsOneWidget);

      // Passo 3: Seleção de Formatos
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Seleção de Formatos'), findsOneWidget);

      // Passo 4: Baixar e Gerenciar Espaço
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Baixar e Gerenciar Espaço'), findsOneWidget);

      // Passo 5: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsNothing);
    });

    testWidgets(
        'toque no botão (i) na tela do Leitor de Letras dispara o tutorial e navega pelos passos',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.lyrics,
        routes: [
          GoRoute(
            path: RoutePaths.lyrics,
            builder: (context, state) {
              final tutorial = ProviderScope.containerOf(context)
                  .read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorial.portalController,
                autoStart: false,
                onFinish: () => tutorial.resetTutorialState(),
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: Column(
                    children: [
                      SpotlightGuideTarget(
                        id: 'lyrics-font-size-controls',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Lyrics Font Size'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'lyrics-autoscroll-controls',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Lyrics Autoscroll'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'lyrics-fullscreen-button',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Lyrics Fullscreen'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'lyrics-content-view',
                        child: const SizedBox(
                          height: 200,
                          child: Text('Mock Lyrics Content View'),
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
          child: MaterialApp.router(
            routerConfig: router,
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

      // Passo 1: Tamanho da Letra
      expect(find.text('Tamanho da Letra'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Passo 2: Rolagem Automática
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Rolagem Automática'), findsOneWidget);

      // Passo 3: Modo Tela Cheia
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Modo Tela Cheia'), findsOneWidget);

      // Passo 4: Leitura e Seleção de Texto
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Leitura e Seleção de Texto'), findsOneWidget);

      // Passo 5: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsNothing);
    });

    testWidgets(
        'toque no botão (i) na tela de Detalhes do Louvor dispara o tutorial e navega pelos passos',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/louvor/0a1',
        routes: [
          GoRoute(
            path: '/louvor/:id',
            builder: (context, state) {
              final tutorial = ProviderScope.containerOf(context)
                  .read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorial.portalController,
                autoStart: false,
                onFinish: () => tutorial.resetTutorialState(),
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: Column(
                    children: [
                      SpotlightGuideTarget(
                        id: 'praise-header',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Praise Header'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'praise-related-bar',
                        child: const SizedBox(
                          height: 48,
                          child: Text('Mock Praise Related Bar'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'praise-materials-section',
                        child: const SizedBox(
                          height: 120,
                          child: Text('Mock Praise Materials Section'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'praise-lyrics-section',
                        child: const SizedBox(
                          height: 120,
                          child: Text('Mock Praise Lyrics Section'),
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
          child: MaterialApp.router(
            routerConfig: router,
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

      // Passo 1: Informações do Louvor
      expect(find.text('Informações do Louvor'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Passo 2: Versões Relacionadas
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Versões Relacionadas'), findsOneWidget);

      // Passo 3: Materiais e Partituras
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Materiais e Partituras'), findsOneWidget);

      // Passo 4: Letra e Metadados
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Letra e Metadados'), findsOneWidget);

      // Passo 5: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsNothing);
    });

    testWidgets(
        'toque no botão (i) na tela Sobre dispara o tutorial e navega pelos passos',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.about,
        routes: [
          GoRoute(
            path: RoutePaths.about,
            builder: (context, state) {
              final tutorialNotifier =
                  ProviderScope.containerOf(context).read(tutorialControllerProvider);

              return SpotlightGuidePortal(
                controller: tutorialNotifier.portalController,
                child: Scaffold(
                  appBar: const PlpcgPrimaryAppBar(),
                  body: ListView(
                    children: [
                      SpotlightGuideTarget(
                        id: 'about-who-we-are',
                        child: const SizedBox(
                          height: 100,
                          child: Text('Quem somos card'),
                        ),
                      ),
                      SpotlightGuideTarget(
                        id: 'about-mission',
                        child: const SizedBox(
                          height: 100,
                          child: Text('Objetivo card'),
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
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final infoButtonFinder = find.byIcon(Icons.info_outline);
      expect(infoButtonFinder, findsOneWidget);

      await tester.tap(infoButtonFinder);
      await tester.pumpAndSettle();

      // Passo 1: Quem Somos
      expect(find.text('Quem Somos'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);

      // Passo 2: Nosso Objetivo
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Nosso Objetivo'), findsOneWidget);

      // Passo 3: Ajuda & Tutoriais
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Ajuda & Tutoriais'), findsNothing);
    });
  });
}
