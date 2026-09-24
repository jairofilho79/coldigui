import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/features/catalog/presentation/pages/home_screen.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/library/presentation/pages/library_screen.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

/// Página inicial e /biblioteca vivem em ramos distintos de um
/// `StatefulShellRoute.indexedStack` (como no app): o ramo visitado fica
/// montado fora de cena e continua a ouvir `catalogFiltersProvider`. Mexer
/// num filtro numa aba não pode levar o usuário para a outra.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    required String initialLocation,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.home,
                  builder: (context, state) {
                    final params = state.uri.queryParameters;
                    return HomeScreen(
                      initialSearchQuery: params[UrlSyncParams.pesquisa] ?? '',
                      initialTonality: params[UrlSyncParams.tonality],
                      initialRhythm: params[UrlSyncParams.rhythm],
                      initialCategory: params[UrlSyncParams.category],
                      initialTags: params[UrlSyncParams.tags],
                      initialMaterialKinds: params[UrlSyncParams.materialKinds],
                    );
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.library,
                  builder: (context, state) {
                    final params = state.uri.queryParameters;
                    return LibraryScreen(
                      initialTonality: params[UrlSyncParams.tonality],
                      initialRhythm: params[UrlSyncParams.rhythm],
                      initialCategory: params[UrlSyncParams.category],
                      initialTags: params[UrlSyncParams.tags],
                      initialMaterialKinds: params[UrlSyncParams.materialKinds],
                      initialOrdenar: params[UrlSyncParams.ordenar],
                      initialItensPorPagina:
                          params[UrlSyncParams.itensPorPagina],
                      initialPagina: params[UrlSyncParams.pagina],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...catalogIndexOverrides(
            catalogIndexOf([
              catalogGroup(
                praiseId: 'p1',
                number: '001',
                name: 'Aleluia',
                tonality: 'Dm',
              ),
            ]),
          ),
          // Offline: a busca com `pesquisa=` fica só local, sem rede.
          connectivityStreamProvider.overrideWith(
            (ref) => Stream<bool>.value(false),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Uri currentUri(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri;

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  testWidgets('filtro mexido na página inicial não leva para a /biblioteca', (
    tester,
  ) async {
    final router = await pumpShell(tester, initialLocation: RoutePaths.library);
    router.go(RoutePaths.home);
    await tester.pumpAndSettle();
    expect(currentUri(router).path, RoutePaths.home);

    containerOf(tester)
        .read(catalogFiltersProvider.notifier)
        .toggleTonality('Dm');
    await tester.pumpAndSettle();

    expect(currentUri(router).path, RoutePaths.home);
    expect(currentUri(router).queryParameters[UrlSyncParams.tonality], 'Dm');
  });

  testWidgets('filtro mexido na /biblioteca não leva para a página inicial', (
    tester,
  ) async {
    final router = await pumpShell(
      tester,
      initialLocation: '${RoutePaths.home}?${UrlSyncParams.pesquisa}=aleluia',
    );
    router.go(RoutePaths.library);
    await tester.pumpAndSettle();
    expect(currentUri(router).path, RoutePaths.library);

    containerOf(tester)
        .read(catalogFiltersProvider.notifier)
        .toggleTonality('Dm');
    await tester.pumpAndSettle();

    expect(currentUri(router).path, RoutePaths.library);
    expect(currentUri(router).queryParameters[UrlSyncParams.tonality], 'Dm');
  });
}
