import 'package:coldigui/core/routing/go_router_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Router mínimo com a mesma forma do app: `/leitor` filha de `/`.
GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Text('home'),
        routes: [
          GoRoute(path: 'leitor', builder: (_, _) => const Text('leitor')),
        ],
      ),
    ],
  );
}

void main() {
  final original = GoRouter.optionURLReflectsImperativeAPIs;
  tearDown(() => GoRouter.optionURLReflectsImperativeAPIs = original);

  testWidgets('sem a opção, push não muda a URL reportada (controle)', (
    tester,
  ) async {
    GoRouter.optionURLReflectsImperativeAPIs = false;
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/leitor?file=x');
    await tester.pumpAndSettle();

    expect(find.text('leitor'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('configureGoRouterGlobals faz push refletir na URL (P2)', (
    tester,
  ) async {
    configureGoRouterGlobals();
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/leitor?file=x');
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/leitor');
    expect(uri.queryParameters['file'], 'x');
  });

  testWidgets('replace na rota empilhada também reflete na URL (P2)', (
    tester,
  ) async {
    configureGoRouterGlobals();
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/leitor?file=x');
    await tester.pumpAndSettle();
    router.replace('/leitor?file=y');
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.queryParameters['file'],
      'y',
    );
  });
}
