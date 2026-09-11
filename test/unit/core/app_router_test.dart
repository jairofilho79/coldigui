import 'package:coldigui/core/constants/app_tabs.dart';
import 'package:coldigui/core/constants/feature_flags.dart';
import 'package:coldigui/core/providers/feature_flags_provider.dart';
import 'package:coldigui/core/routing/app_router.dart';
import 'package:coldigui/core/routing/route_paths.dart';
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

    test('com social: false, /social não é registrada', () {
      final router = buildRouter(const FeatureFlags(social: false));

      final match = router.configuration.findMatch(
        Uri.parse(RoutePaths.social),
      );

      expect(match.isError, isTrue);
    });

    test('com as flags padrão, /social continua registrada', () {
      final router = buildRouter(const FeatureFlags());

      final match = router.configuration.findMatch(
        Uri.parse(RoutePaths.social),
      );

      expect(match.isError, isFalse);
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

      final shellRoute =
          router.configuration.routes.single as StatefulShellRoute;

      expect(shellRoute.branches.length, appTabsFor(flags).length);
    });
  });
}
