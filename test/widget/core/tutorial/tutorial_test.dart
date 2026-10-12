import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/tutorial/presentation/providers/tutorial_provider.dart';
import 'package:coldigui/core/widgets/plpcg_primary_app_bar.dart';
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
        MaterialApp(
          home: Builder(
            builder: (context) {
              final controller = TutorialController();
              final steps = controller.stepsForRoute(context, RoutePaths.home);
              expect(steps.length, greaterThanOrEqualTo(4));
              expect(steps.first.items.first.targetId, 'home-search-bar');
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('toque no botão (i) na AppBar dispara o tutorial',
        (tester) async {
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
                  body: SpotlightGuideTarget(
                    id: 'home-search-bar',
                    child: const Text('Conteúdo Home'),
                  ),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
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

      // Verifica se o balão de tutorial foi exibido com o título do primeiro passo
      expect(find.text('Pesquisa Inteligente'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);
    });
  });
}
