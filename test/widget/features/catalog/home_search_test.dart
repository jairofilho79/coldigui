import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/catalog/presentation/pages/home_screen.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_worker.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  @override
  List<CarouselItem> build() => const [];
}

List<Override> _homeSearchTestOverrides({
  required SharedPreferences prefs,
  required List<Louvor> catalog,
}) {
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    louvoresManifestProvider.overrideWith(
      (ref) async => LouvoresManifest.fromLouvores(catalog),
    ),
    carouselLouvoresProvider.overrideWith(_FakeCarouselNotifier.new),
    homeSearchPipelineExecutorProvider.overrideWith(
      (ref) => (input) async => runHomeSearchPipeline(input),
    ),
  ];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen exibe LouvorCard após debounce de busca',
      (tester) async {
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

      expect(find.textContaining('Louvor duzentos e cinquenta e oito'),
          findsOneWidget);
      expect(find.textContaining('Louvor número dois'), findsNothing);
      expect(tester.widget<TextField>(field).controller!.text, '258');
    },
  );
}
