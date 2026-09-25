import 'package:coldigui/core/routing/reading_navigation.dart';
import 'package:coldigui/core/routing/route_paths.dart';
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

  Map<Object?, Object?>? get lastUpdateArgs {
    for (final call in calls.reversed) {
      if (call.method == 'routeInformationUpdated') {
        return call.arguments as Map<Object?, Object?>;
      }
    }
    return null;
  }

  void clear() => calls.clear();
}

/// Tela com um botão por destino: cada toque chama [openReadingLocation]
/// com o `context` da própria tela, como fazem os openers do app.
Widget _page(String label) => Builder(
  builder: (context) => Column(
    children: [
      Text('tela=$label'),
      for (final target in [
        RoutePaths.reader,
        RoutePaths.audio,
        RoutePaths.chords,
        RoutePaths.lyrics,
      ])
        TextButton(
          onPressed: () => openReadingLocation(context, '$target?x=1'),
          child: Text('abrir $target'),
        ),
      TextButton(onPressed: () => context.pop(), child: const Text('voltar')),
    ],
  ),
);

GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: RoutePaths.home,
        builder: (_, _) => _page('home'),
        routes: [
          GoRoute(path: 'leitor', builder: (_, _) => _page('leitor')),
          GoRoute(path: 'audio', builder: (_, _) => _page('audio')),
          GoRoute(path: 'cifra', builder: (_, _) => _page('cifra')),
          GoRoute(path: 'letra', builder: (_, _) => _page('letra')),
        ],
      ),
    ],
  );
}

void main() {
  setUp(() => GoRouter.optionURLReflectsImperativeAPIs = true);
  tearDown(() => GoRouter.optionURLReflectsImperativeAPIs = false);

  Future<GoRouter> pumpApp(WidgetTester tester) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('fora da leitura empilha: da Pesquisa para o leitor é push', (
    tester,
  ) async {
    final spy = _NavigationChannelSpy()..install(tester);
    final router = await pumpApp(tester);
    spy.clear();

    await tapText(tester, 'abrir ${RoutePaths.reader}');

    expect(find.text('tela=leitor'), findsOneWidget);
    expect(router.canPop(), isTrue);
    expect(spy.lastUpdateArgs?['replace'], isFalse);
  });

  testWidgets('dentro da leitura troca sem empilhar (leitor → áudio → '
      'cifra → letra → leitor) e voltar cai na Pesquisa', (tester) async {
    final spy = _NavigationChannelSpy()..install(tester);
    await pumpApp(tester);
    await tapText(tester, 'abrir ${RoutePaths.reader}');

    for (final (target, label) in [
      (RoutePaths.audio, 'audio'),
      (RoutePaths.chords, 'cifra'),
      (RoutePaths.lyrics, 'letra'),
      (RoutePaths.reader, 'leitor'),
    ]) {
      spy.clear();
      await tapText(tester, 'abrir $target');
      expect(find.text('tela=$label'), findsOneWidget);
      final args = spy.lastUpdateArgs;
      expect(args, isNotNull, reason: 'nada reportado ao abrir $target');
      expect(args!['uri'], contains(target));
      // Histórico do navegador também não cresce (replaceState).
      expect(args['replace'], isTrue, reason: 'abrir $target');
    }

    await tapText(tester, 'voltar');
    expect(find.text('tela=home'), findsOneWidget);
  });
}
