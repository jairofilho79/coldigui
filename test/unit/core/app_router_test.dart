import 'package:coldigui/core/constants/app_tabs.dart';
import 'package:coldigui/core/constants/feature_flags.dart';
import 'package:coldigui/core/providers/feature_flags_provider.dart';
import 'package:coldigui/core/routing/app_router.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// E6 — `appRouterProvider` monta suas `StatefulShellBranch` a partir de
/// `appTabsFor(featureFlagsProvider)`. Usa `router.configuration.findMatch`
/// (o mesmo método que o parser do GoRouter chama internamente) em vez de
/// navegar de fato — evita depender de providers pesados (Isar, auth,
/// manifest) só para verificar registro de rota.
void main() {
  GoRouter buildRouter(FeatureFlags flags) {
    final container = ProviderContainer(
      overrides: [featureFlagsProvider.overrideWithValue(flags)],
    );
    addTearDown(container.dispose);
    return container.read(appRouterProvider);
  }

  group('appRouterProvider — abas derivadas de appTabsFor (E6)', () {
    test('com as flags padrão (FF_EVENTS=false), /eventos não é registrada '
        '— match de erro, sem lançar', () {
      final router = buildRouter(const FeatureFlags());

      final match = router.configuration.findMatch(
        Uri.parse(RoutePaths.events),
      );

      expect(match.isError, isTrue);
    });

    test('com events: true, /eventos é registrada e casa normalmente', () {
      final router = buildRouter(const FeatureFlags(events: true));

      final match = router.configuration.findMatch(
        Uri.parse(RoutePaths.events),
      );

      expect(match.isError, isFalse);
    });

    test('com social: false, /listas/publicas não é registrada', () {
      final router = buildRouter(const FeatureFlags(social: false));

      final match = router.configuration.findMatch(
        Uri.parse(RoutePaths.publicPlaylists),
      );

      expect(match.isError, isTrue);
    });

    test('com as flags padrão, /listas/publicas é registrada', () {
      final router = buildRouter(const FeatureFlags());

      final match = router.configuration.findMatch(
        Uri.parse(RoutePaths.publicPlaylists),
      );

      expect(match.isError, isFalse);
    });

    test('/listas e /biblioteca continuam registradas com qualquer flag', () {
      final router = buildRouter(
        const FeatureFlags(events: true, social: false),
      );

      expect(
        router.configuration.findMatch(Uri.parse(RoutePaths.playlists)).isError,
        isFalse,
      );
      expect(
        router.configuration.findMatch(Uri.parse(RoutePaths.library)).isError,
        isFalse,
      );
    });

    testWidgets('/social (aba antiga) redireciona para /listas/publicas', (
      tester,
    ) async {
      final router = buildRouter(const FeatureFlags());
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final legacyMatch = router.configuration.findMatch(
        Uri.parse(RoutePaths.social),
      );
      expect(legacyMatch.isError, isTrue);

      final redirected = await Future.value(
        router.configuration.redirect(
          context,
          legacyMatch,
          redirectHistory: [],
        ),
      );

      expect(redirected.isError, isFalse);
      expect(redirected.uri.path, RoutePaths.publicPlaylists);
    });

    testWidgets(
      '/social com social: false vai direto para a Home (sem página de erro)',
      (tester) async {
        final router = buildRouter(const FeatureFlags(social: false));
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (innerContext) {
                context = innerContext;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final legacyMatch = router.configuration.findMatch(
          Uri.parse(RoutePaths.social),
        );
        expect(legacyMatch.isError, isTrue);

        final redirected = await Future.value(
          router.configuration.redirect(
            context,
            legacyMatch,
            redirectHistory: [],
          ),
        );

        expect(redirected.isError, isFalse);
        expect(redirected.uri.path, RoutePaths.home);
      },
    );

    test('/listas/publicas é aninhada em /listas (pilha de 2 matches)', () {
      final router = buildRouter(const FeatureFlags());

      final match = router.configuration.findMatch(
        Uri.parse(RoutePaths.publicPlaylists),
      );
      expect(match.isError, isFalse);

      // `findMatch` devolve um único `ShellRouteMatch` de nível superior
      // (a `StatefulShellRoute`); a pilha de rotas de fato (`/listas` +
      // `/listas/publicas`) mora em `ShellRouteMatch.matches`.
      final shellMatch = match.matches.single as ShellRouteMatch;
      expect(shellMatch.matches.length, 2);
      expect(shellMatch.matches.first.matchedLocation, RoutePaths.playlists);
    });

    test(
      'a Home (initialLocation) sempre casa, com qualquer combinação de flags',
      () {
        final router = buildRouter(
          const FeatureFlags(events: true, social: false),
        );

        final match = router.configuration.findMatch(
          Uri.parse(RoutePaths.home),
        );

        expect(match.isError, isFalse);
      },
    );

    test('número de StatefulShellBranch bate com appTabsFor(flags).length — '
        'índices de branch nunca fixos', () {
      const flags = FeatureFlags(events: true, social: false);
      final router = buildRouter(flags);

      // `.routes` (não `.single`): `/contribuir` é uma rota irmã no
      // navigator raiz desde a Tarefa 4 — o shell continua sendo o único
      // `StatefulShellRoute`, só não é mais a única rota de nível superior.
      final shellRoute = router.configuration.routes
          .whereType<StatefulShellRoute>()
          .single;

      expect(shellRoute.branches.length, appTabsFor(flags).length);
    });

    // Fix round: rota desconhecida/escondida (`/eventos` com a flag
    // desligada) não pode parar na página de erro padrão do GoRouter —
    // redireciona pra Home. O `redirect` de nível superior roda mesmo sobre
    // um match de erro (é assim que o próprio GoRouter processa a
    // navegação: `applyTopLegacyRedirect` chama o `redirect` do app com o
    // `GoRouterState` do match, com ou sem erro), então exercitamos o mesmo
    // caminho aqui — sem montar a árvore de widgets pesada do shell.
    testWidgets(
      '/eventos com FF_EVENTS=false não fica na rota de erro do GoRouter — '
      'redireciona pra Home',
      (tester) async {
        final router = buildRouter(const FeatureFlags());
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (innerContext) {
                context = innerContext;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final errorMatch = router.configuration.findMatch(
          Uri.parse(RoutePaths.events),
        );
        expect(errorMatch.isError, isTrue);

        final redirected = await Future.value(
          router.configuration.redirect(
            context,
            errorMatch,
            redirectHistory: [],
          ),
        );

        expect(redirected.isError, isFalse);
        expect(redirected.uri.path, RoutePaths.home);
      },
    );
  });
}
