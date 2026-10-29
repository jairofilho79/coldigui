import 'package:coldigui/core/routing/url_sync_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Captura o que o Router reporta ao navegador (`routeInformationUpdated`):
/// é o mesmo canal que, na web, vira `history.pushState`/`replaceState`.
class _NavigationChannelSpy {
  final List<MethodCall> calls = [];

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      ),
    );
  }

  /// Último `routeInformationUpdated` — `null` se nenhum foi reportado.
  MethodCall? get lastUpdate {
    for (final call in calls.reversed) {
      if (call.method == 'routeInformationUpdated') return call;
    }
    return null;
  }

  void clear() => calls.clear();
}

GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Column(
          children: [
            Text('q=${state.uri.queryParameters['pesquisa'] ?? ''}'),
            TextButton(
              onPressed: () => goReplacingUrl(
                context,
                GoRouter.of(context),
                '/?pesquisa=abc',
              ),
              child: const Text('sync'),
            ),
            TextButton(
              onPressed: () => GoRouter.of(context).go('/?pesquisa=xyz'),
              child: const Text('go'),
            ),
          ],
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('goReplacingUrl navega e reporta replace=true (P4)', (
    tester,
  ) async {
    final spy = _NavigationChannelSpy()..install(tester);
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    spy.clear();

    await tester.tap(find.text('sync'));
    await tester.pumpAndSettle();

    expect(find.text('q=abc'), findsOneWidget);
    final update = spy.lastUpdate;
    expect(update, isNotNull, reason: 'nada foi reportado ao navegador');
    final args = update!.arguments as Map<Object?, Object?>;
    expect(args['uri'], contains('pesquisa=abc'));
    expect(args['replace'], isTrue);
  });

  testWidgets('go comum reporta replace=false (controle)', (tester) async {
    final spy = _NavigationChannelSpy()..install(tester);
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    spy.clear();

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('q=xyz'), findsOneWidget);
    final args = spy.lastUpdate!.arguments as Map<Object?, Object?>;
    expect(args['uri'], contains('pesquisa=xyz'));
    expect(args['replace'], isFalse);
  });
}
