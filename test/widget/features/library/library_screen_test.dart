import 'dart:async';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card_skeleton.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/library/presentation/pages/library_screen.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

List<LouvorGroup> _groups(int count) => [
  for (var i = 1; i <= count; i++)
    catalogGroup(
      praiseId: 'p$i',
      number: '$i'.padLeft(3, '0'),
      name: 'Louvor $i',
    ),
];

Widget _libraryTestApp({
  required SharedPreferences prefs,
  required List<Override> catalogOverrides,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...catalogOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const Scaffold(body: LibraryScreen()),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLibrary(
    WidgetTester tester,
    List<LouvorGroup> groups,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _libraryTestApp(
        prefs: prefs,
        catalogOverrides: catalogIndexOverrides(catalogIndexOf(groups)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista os louvores do índice local, sem seletor de fonte', (
    tester,
  ) async {
    await pumpLibrary(tester, _groups(15));

    expect(find.text('#001 — Louvor 1'), findsOneWidget);
    // O seletor «Fonte: PLPCG | Coldigom» não existe mais.
    expect(find.text('Fonte'), findsNothing);
  });

  testWidgets('resumo dentro do card Visualização', (tester) async {
    await pumpLibrary(tester, _groups(15));

    final summary = find.textContaining('Mostrando 1');
    expect(summary, findsOneWidget);
    expect(find.text('10 por página'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: summary,
          matching: find.byType(GoldenTaggedContainer),
        ),
        matching: find.text('Visualização'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('troca página e ordenação', (tester) async {
    await pumpLibrary(tester, _groups(15));

    expect(find.text('#001 — Louvor 1'), findsOneWidget);
    expect(find.text('#011 — Louvor 11'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('#011 — Louvor 11'), findsOneWidget);
    expect(find.text('#001 — Louvor 1'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('#001 — Louvor 1'), findsOneWidget);

    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('#001 — Louvor 1')).dy,
      lessThan(tester.getTopLeft(find.text('#010 — Louvor 10')).dy),
    );
  });

  testWidgets('skeleton enquanto o índice hidrata', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    final pending = Completer<ColdigomSearchIndex>();

    await tester.pumpWidget(
      _libraryTestApp(
        prefs: prefs,
        catalogOverrides: [
          coldigomCatalogHydrationProvider.overrideWith(
            (ref) => pending.future,
          ),
          coldigomCatalogSyncProvider.overrideWith(
            FakeColdigomCatalogSyncNotifier.new,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(LouvorGroupCardSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('o painel de filtros usa o índice e filtra a lista', (
    tester,
  ) async {
    await pumpLibrary(tester, [
      catalogGroup(
        praiseId: 'p1',
        number: '001',
        name: 'Louvor 1',
        tonality: 'Dm',
      ),
      catalogGroup(
        praiseId: 'p2',
        number: '002',
        name: 'Louvor 2',
        tonality: 'G',
      ),
    ]);

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    final dm = find.widgetWithText(FilterChip, 'Dm');
    await tester.ensureVisible(dm);
    await tester.tap(dm);
    await tester.pumpAndSettle();

    expect(find.text('#001 — Louvor 1'), findsOneWidget);
    expect(find.text('#002 — Louvor 2'), findsNothing);
  });

  testWidgets(
    'sync da URL leva os filtros e tira os params mortos (fonte, materiais, '
    'arranjo, arranjoEspecial)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        initialLocation:
            '${RoutePaths.library}?fonte=coldigom&materiais=Partitura'
            '&arranjo=ColAdultos&arranjoEspecial=Especial&tags=PES',
        routes: [
          GoRoute(
            path: RoutePaths.library,
            builder: (context, state) {
              final params = state.uri.queryParameters;
              return Scaffold(
                body: LibraryScreen(
                  initialTonality: params[UrlSyncParams.tonality],
                  initialRhythm: params[UrlSyncParams.rhythm],
                  initialCategory: params[UrlSyncParams.category],
                  initialTags: params[UrlSyncParams.tags],
                  initialMaterialKinds: params[UrlSyncParams.materialKinds],
                  initialOrdenar: params[UrlSyncParams.ordenar],
                  initialItensPorPagina: params[UrlSyncParams.itensPorPagina],
                  initialPagina: params[UrlSyncParams.pagina],
                ),
              );
            },
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
                for (var i = 1; i <= 15; i++)
                  catalogGroup(
                    praiseId: 'p$i',
                    number: '$i'.padLeft(3, '0'),
                    name: 'Louvor $i',
                    tonality: 'Dm',
                    tags: const ['PES'],
                  ),
                catalogGroup(
                  praiseId: 'p99',
                  number: '099',
                  name: 'Fora',
                  tonality: 'G',
                  tags: const ['CIAs'],
                ),
              ]),
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

      Map<String, String> query() =>
          router.routerDelegate.currentConfiguration.uri.queryParameters;

      // A URL hidratou o filtro de tags: o painel abre e a lista já filtra.
      expect(find.text('#099 — Fora'), findsNothing);

      final dm = find.widgetWithText(FilterChip, 'Dm');
      await tester.ensureVisible(dm);
      await tester.tap(dm);
      await tester.pumpAndSettle();

      expect(query()[UrlSyncParams.tags], 'PES');
      expect(query()[UrlSyncParams.tonality], 'Dm');
      for (final dead in ['fonte', 'materiais', 'arranjo', 'arranjoEspecial']) {
        expect(query(), isNot(contains(dead)), reason: dead);
      }

      // Mudar a vista (página) mantém os filtros na URL.
      final next = find.byIcon(Icons.chevron_right);
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();

      expect(query()[UrlSyncParams.pagina], '2');
      expect(query()[UrlSyncParams.tags], 'PES');
      expect(query()[UrlSyncParams.tonality], 'Dm');
    },
  );
}
