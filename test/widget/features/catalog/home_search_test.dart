import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/platform/platform_capabilities.dart';
import 'package:coldigui/core/platform/platform_capabilities_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/domain/ports/search_cancellation.dart';
import 'package:coldigui/features/catalog/presentation/pages/home_screen.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_bar.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/domain/repositories/coldigom_search_repository.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _louvor({required String nome, required String numero}) =>
    Louvor.fromManifest(
      nome: nome,
      numero: numero,
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '$numero.pdf',
      pdfId: 'id-$numero',
    );

LouvorGroup _group(Louvor louvor) => LouvorGroup(
  groupId: 'cg-${louvor.numero}',
  numero: louvor.numero,
  nome: louvor.nome,
  sections: [
    LouvorMaterialSection(
      classificacao: louvor.classificacao,
      displayLabel: louvor.classificacao,
      materials: [
        LouvorMaterialEntry(
          categoria: louvor.categoria,
          pdfId: louvor.pdfId,
          louvor: louvor,
        ),
      ],
    ),
  ],
);

class _FakeColdigomRepo implements ColdigomSearchRepository {
  _FakeColdigomRepo(this.catalog);

  final List<Louvor> catalog;

  @override
  Future<ColdigomSearchResult> search(
    String query, {
    int page = 1,
    SearchCancellation? cancellation,
  }) async {
    final q = query.trim().toLowerCase();
    final matched = catalog
        .where(
          (l) =>
              l.numero.toLowerCase().contains(q) ||
              l.nome.toLowerCase().contains(q),
        )
        .toList();
    final groups = matched.map(_group).toList();
    return ColdigomSearchResult(
      groups: groups,
      louvores: matched,
      page: page,
      hasNextPage: false,
    );
  }

  @override
  Future<ColdigomBrowseResult> browse(ColdigomBrowseQuery query) async {
    return const ColdigomBrowseResult(
      groups: [],
      louvores: [],
      page: 1,
      limit: 10,
      totalItems: 0,
      totalPages: 0,
    );
  }
}

/// Repositório coldigom que falha até o teste liberar — cobre a linha de
/// "indisponível", o retry manual e a reconexão.
class _ScriptedColdigomRepo implements ColdigomSearchRepository {
  var shouldFail = true;
  var calls = 0;

  @override
  Future<ColdigomSearchResult> search(
    String query, {
    int page = 1,
    SearchCancellation? cancellation,
  }) async {
    calls++;
    if (shouldFail) throw Exception('coldigom indisponível');
    return ColdigomSearchResult(
      groups: const [],
      louvores: const [],
      page: page,
      hasNextPage: false,
    );
  }

  @override
  Future<ColdigomBrowseResult> browse(ColdigomBrowseQuery query) async {
    return const ColdigomBrowseResult(
      groups: [],
      louvores: [],
      page: 1,
      limit: 10,
      totalItems: 0,
      totalPages: 0,
    );
  }
}

List<Override> _homeSearchTestOverrides({
  required SharedPreferences prefs,
  required List<Louvor> catalog,
  ColdigomSearchRepository? coldigom,
  List<Override> extra = const [],
}) {
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    louvoresManifestOverride(LouvoresManifest.fromLouvores(catalog)),
    // Acervo vazio: estes testes medem debounce/eco de URL sobre a busca PLPCG.
    // Alimentar o mesmo catálogo nas duas fontes duplicaria cada resultado —
    // artefato da fixture, não do produto. Coldigom tem cobertura própria em
    // test/unit/features/coldigom/coldigom_search_repository_test.dart.
    coldigomSearchRepositoryProvider.overrideWithValue(
      coldigom ?? _FakeColdigomRepo(const []),
    ),
    ...extra,
  ];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen exibe LouvorCard após debounce de busca', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final catalog = [
      _louvor(nome: 'Aleluia', numero: '001'),
      _louvor(nome: 'São João', numero: '002'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: _homeSearchTestOverrides(prefs: prefs, catalog: catalog),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '001');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aleluia'), findsOneWidget);
    expect(find.textContaining('São João'), findsNothing);
  });

  testWidgets(
    'digitação rápida após debounce não é sobrescrita pelo eco de sync URL',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final catalog = [
        _louvor(nome: 'Louvor número dois', numero: '2'),
        _louvor(nome: 'Louvor duzentos e cinquenta e oito', numero: '258'),
      ];

      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, state) => HomeScreen(
              initialSearchQuery: state.uri.queryParameters['pesquisa'] ?? '',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _homeSearchTestOverrides(prefs: prefs, catalog: catalog),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byType(TextField);

      await tester.enterText(field, '2');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(field, '258');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Louvor duzentos e cinquenta e oito'),
        findsOneWidget,
      );
      expect(find.textContaining('Louvor número dois'), findsNothing);
      expect(tester.widget<TextField>(field).controller!.text, '258');
    },
  );

  testWidgets(
    'falha remota mostra a linha de retry e o toque re-busca a mesma página',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final catalog = [_louvor(nome: 'Aleluia', numero: '001')];
      final repo = _ScriptedColdigomRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _homeSearchTestOverrides(
            prefs: prefs,
            catalog: catalog,
            coldigom: repo,
          ),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '001');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        find.text('Em cache · não foi possível verificar'),
        findsOneWidget,
      );
      // O resultado PLPCG segue na tela apesar da falha remota.
      expect(find.textContaining('Aleluia'), findsOneWidget);

      repo.shouldFail = false;
      await tester.tap(find.text('Em cache · não foi possível verificar'));
      await tester.pumpAndSettle();

      expect(find.text('Em cache · não foi possível verificar'), findsNothing);
      expect(repo.calls, 2);
    },
  );

  testWidgets('reconexão re-busca a página remota quando ela está em erro', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final catalog = [_louvor(nome: 'Aleluia', numero: '001')];
    final repo = _ScriptedColdigomRepo();
    final connectivity = StreamController<bool>.broadcast();
    addTearDown(connectivity.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _homeSearchTestOverrides(
          prefs: prefs,
          catalog: catalog,
          coldigom: repo,
          extra: [
            connectivityStreamProvider.overrideWith(
              (ref) => connectivity.stream,
            ),
          ],
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '001');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Em cache · não foi possível verificar'), findsOneWidget);
    expect(repo.calls, 1);

    repo.shouldFail = false;
    connectivity.add(true);
    await tester.pumpAndSettle();

    expect(find.text('Em cache · não foi possível verificar'), findsNothing);
    expect(repo.calls, 2);
  });

  testWidgets(
    'SearchBar mantém texto digitado quando initialValue muda por eco de URL',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: SearchBar(
              hintText: 'Buscar',
              initialValue: '',
              onQueryChanged: (_) {},
            ),
          ),
        ),
      );

      final field = find.byType(TextField);
      await tester.enterText(field, 'hello');
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: SearchBar(
              hintText: 'Buscar',
              initialValue: 'hell',
              onQueryChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.widget<TextField>(field).controller!.text, 'hello');
    },
  );

  testWidgets(
    'SearchBar autofoca com capabilities.isWeb=true, mesmo sem ProviderScope '
    '(T2 — currentPlatformCapabilities() só como default do parâmetro)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: SearchBar(
              hintText: 'Buscar',
              onQueryChanged: (_) {},
              capabilities: PlatformCapabilities.web,
            ),
          ),
        ),
      );

      // Plataforma de teste é Android (não-desktop, `defaultTargetPlatform`):
      // sem `capabilities.isWeb`, o autofoco ficaria false (UC-01, C1).
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
    },
  );

  testWidgets(
    'HomeScreen repassa platformCapabilitiesProvider ao SearchBar (T2 — '
    'sem currentPlatformCapabilities() direto no widget)',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final catalog = [_louvor(nome: 'Aleluia', numero: '001')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: _homeSearchTestOverrides(
            prefs: prefs,
            catalog: catalog,
            extra: [
              platformCapabilitiesProvider.overrideWithValue(
                PlatformCapabilities.web,
              ),
            ],
          ),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
    },
  );
}
