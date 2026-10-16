import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/tutorial/presentation/providers/tutorial_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/filters_panel.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<(ProviderContainer, SharedPreferences)> pumpFiltersPanel(
    WidgetTester tester, {
    CatalogFilterScope scope = CatalogFilterScope.home,
    bool initiallyExpanded = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...catalogIndexOverrides(
          catalogIndexOf([
            catalogGroup(
              praiseId: 'p1',
              number: '001',
              name: 'Aleluia',
              tonality: 'Dm',
              rhythm: 'Fox',
              tags: const ['PES'],
            ),
          ]),
        ),
        connectivityStreamProvider.overrideWith(
          (ref) => const Stream<bool>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final tutorialController = container.read(tutorialControllerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: SpotlightGuidePortal(
            controller: tutorialController.portalController,
            autoStart: false,
            onFinish: () => tutorialController.resetTutorialState(),
            child: Scaffold(
              body: SingleChildScrollView(
                child: FiltersPanel(
                  scope: scope,
                  initiallyExpanded: initiallyExpanded,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container, prefs);
  }

  group('FiltersPanel Spotlight Tutorial Targets', () {
    testWidgets('exibe alvo de ajuda filters-info no cabeçalho quando expandido', (
      tester,
    ) async {
      await pumpFiltersPanel(tester, initiallyExpanded: false);
      expect(
        find.byWidgetPredicate(
          (w) => w is SpotlightGuideTarget && w.id == 'filters-info',
        ),
        findsNothing,
      );

      // Expande o painel
      await tester.tap(find.text('Toque para ver mais'));
      await tester.pumpAndSettle();

      final infoFinder = find.byWidgetPredicate(
        (w) => w is SpotlightGuideTarget && w.id == 'filters-info',
      );
      expect(infoFinder, findsOneWidget);

      final iconBtnFinder = find.widgetWithIcon(IconButton, Icons.info_outline);
      expect(iconBtnFinder, findsOneWidget);
    });

    testWidgets('exibe alvos de seções quando o painel está expandido', (
      tester,
    ) async {
      await pumpFiltersPanel(tester, initiallyExpanded: true);

      expect(
        find.byWidgetPredicate(
          (w) => w is SpotlightGuideTarget && w.id == 'filters-tonality-section',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SpotlightGuideTarget && w.id == 'filters-rhythm-section',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SpotlightGuideTarget && w.id == 'filters-category-section',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SpotlightGuideTarget && w.id == 'filters-material-kind',
        ),
        findsOneWidget,
      );
    });

    testWidgets('exibe alvo filters-clear-action quando há filtros ativos', (
      tester,
    ) async {
      final (container, _) = await pumpFiltersPanel(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is SpotlightGuideTarget && w.id == 'filters-clear-action',
        ),
        findsNothing,
      );

      container.read(homeCatalogFiltersProvider.notifier).toggleTonality('Dm');
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is SpotlightGuideTarget && w.id == 'filters-clear-action',
        ),
        findsOneWidget,
      );
    });

    testWidgets('toque no botão filters-info inicia o tutorial de filtros e exibe os passos', (
      tester,
    ) async {
      final (container, _) = await pumpFiltersPanel(tester, initiallyExpanded: true);

      final tutorialController = container.read(tutorialControllerProvider);
      expect(tutorialController.portalController.isShowing, isFalse);

      final infoBtn = find.widgetWithIcon(IconButton, Icons.info_outline);
      await tester.tap(infoBtn);
      await tester.pumpAndSettle();

      // Painel deve ter auto-expandido pelo tutorialController
      expect(
        container.read(filtersPanelExpandedOverrideProvider(CatalogFilterScope.home)),
        isTrue,
      );
      expect(tutorialController.portalController.isShowing, isTrue);
      expect(find.text('Filtro por Tonalidade'), findsOneWidget);
    });
  });
}
