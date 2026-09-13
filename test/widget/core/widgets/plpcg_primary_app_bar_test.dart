import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/widgets/plpcg_primary_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Spec D2 — em `/listas/publicas` a barra mostra a seta de voltar (mesmo
/// padrão das rotas imersivas); em `/listas` não. Sub-páginas do Perfil
/// (`/biblioteca`, `/offline`, `/sobre`, `/materiais-favoritos`) voltam para
/// `/perfil`.
void main() {
  Widget page(String label) =>
      Scaffold(appBar: const PlpcgPrimaryAppBar(), body: Text(label));

  GoRouter buildRouter(String initialLocation) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RoutePaths.playlists,
          builder: (_, _) => const Scaffold(
            appBar: PlpcgPrimaryAppBar(),
            body: Text('Listas'),
          ),
          routes: [
            GoRoute(
              path: 'publicas',
              builder: (_, _) => const Scaffold(
                appBar: PlpcgPrimaryAppBar(),
                body: Text('Públicas'),
              ),
            ),
          ],
        ),
        // Branch Perfil: rotas irmãs, sem pilha — a seta cai no `go('/perfil')`.
        GoRoute(path: RoutePaths.profile, builder: (_, _) => page('Perfil')),
        GoRoute(
          path: RoutePaths.library,
          builder: (_, _) => page('Biblioteca'),
        ),
        GoRoute(path: RoutePaths.offline, builder: (_, _) => page('Offline')),
        GoRoute(path: RoutePaths.about, builder: (_, _) => page('Sobre')),
        GoRoute(
          path: RoutePaths.favoriteMaterialKinds,
          builder: (_, _) => page('Favoritos'),
        ),
      ],
    );
  }

  Future<void> pump(WidgetTester tester, String location) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter(location)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('em /listas não há seta de voltar', (tester) async {
    await pump(tester, RoutePaths.playlists);

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('em /listas/publicas a seta volta para /listas', (tester) async {
    await pump(tester, RoutePaths.publicPlaylists);
    expect(find.text('Públicas'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Listas'), findsOneWidget);
    expect(find.text('Públicas'), findsNothing);
  });

  testWidgets('em /perfil não há seta de voltar', (tester) async {
    await pump(tester, RoutePaths.profile);

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  for (final (path, label) in [
    (RoutePaths.library, 'Biblioteca'),
    (RoutePaths.offline, 'Offline'),
    (RoutePaths.about, 'Sobre'),
    (RoutePaths.favoriteMaterialKinds, 'Favoritos'),
  ]) {
    testWidgets('em $path a seta volta para /perfil', (tester) async {
      await pump(tester, path);
      expect(find.text(label), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Perfil'), findsOneWidget);
      expect(find.text(label), findsNothing);
    });
  }
}
