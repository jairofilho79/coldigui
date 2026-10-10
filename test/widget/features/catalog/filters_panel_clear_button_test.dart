import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/catalog_filter_sections.dart';
import 'package:coldigui/features/catalog/presentation/widgets/filters_panel.dart';
import 'package:coldigui/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<(ProviderContainer, SharedPreferences)> pumpPanel(
    WidgetTester tester, {
    CatalogFilterScope scope = CatalogFilterScope.home,
    bool initiallyExpanded = false,
    Map<String, Object> prefsValues = const {},
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(prefsValues);
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FiltersPanel(
                scope: scope,
                initiallyExpanded: initiallyExpanded,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container, prefs);
  }

  testWidgets('sem filtros ativos: botão de limpar não é renderizado', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(find.text('Limpar filtros'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets(
    'com filtros ativos: botão de limpar aparece com padrão de estilo da app',
    (tester) async {
      final (container, _) = await pumpPanel(tester);

      // Marca um filtro
      container.read(homeCatalogFiltersProvider.notifier).toggleTonality('Dm');
      await tester.pumpAndSettle();

      final clearFinder = find.widgetWithText(OutlinedButton, 'Limpar filtros');
      expect(clearFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(clearFinder);
      final style = button.style;
      expect(style, isNotNull);

      // Cores e borda do design system (vinho, dourado, pill radius 24)
      expect(style!.foregroundColor?.resolve({}), AppColors.title);
      final side = style.side?.resolve({});
      expect(side?.color, AppColors.gold);
      expect(side?.width, 1.5);
      final shape = style.shape?.resolve({});
      expect(shape, isA<RoundedRectangleBorder>());
      final border = shape as RoundedRectangleBorder;
      expect(border.borderRadius, BorderRadius.circular(24));
    },
  );

  testWidgets(
    'tocar no botão de limpar no painel colapsado esvazia os filtros e não expande o painel',
    (tester) async {
      final (container, prefs) = await pumpPanel(
        tester,
        prefsValues: {
          StorageKeys.catalogFilters: jsonEncode({
            'v': 3,
            'tonalities': ['Dm'],
          }),
        },
      );

      expect(find.byType(CatalogFilterSections), findsNothing);
      expect(find.text('Filtros (1)'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsOneWidget);

      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();

      expect(container.read(homeCatalogFiltersProvider).isEmpty, isTrue);
      expect(prefs.getString(StorageKeys.catalogFilters), isNull);
      expect(find.text('Limpar filtros'), findsNothing);
      expect(find.text('Toque para ver mais'), findsOneWidget);
      // Continua colapsado
      expect(find.byType(CatalogFilterSections), findsNothing);
    },
  );

  testWidgets(
    'tocar no botão de limpar no painel expandido esvazia os filtros e mantém o painel aberto',
    (tester) async {
      final (container, _) = await pumpPanel(tester, initiallyExpanded: true);

      container.read(homeCatalogFiltersProvider.notifier).toggleRhythm('Fox');
      await tester.pumpAndSettle();

      expect(find.byType(CatalogFilterSections), findsOneWidget);
      expect(find.text('Limpar filtros'), findsOneWidget);

      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();

      expect(container.read(homeCatalogFiltersProvider).isEmpty, isTrue);
      expect(find.text('Limpar filtros'), findsNothing);
      // Permanece aberto para o usuário selecionar outros filtros
      expect(find.byType(CatalogFilterSections), findsOneWidget);
    },
  );

  testWidgets(
    'limpar filtros na biblioteca não altera a home e reseta a página da biblioteca para 1',
    (tester) async {
      final (container, prefs) = await pumpPanel(
        tester,
        scope: CatalogFilterScope.library,
        initiallyExpanded: true,
      );

      // Home tem filtro
      container.read(homeCatalogFiltersProvider.notifier).toggleTonality('Dm');
      // Biblioteca tem filtro e página 3
      container
          .read(libraryCatalogFiltersProvider.notifier)
          .toggleRhythm('Fox');
      container.read(libraryViewSettingsProvider.notifier).setPage(3);
      await tester.pumpAndSettle();

      expect(container.read(homeCatalogFiltersProvider).tonalities, {'Dm'});
      expect(container.read(libraryCatalogFiltersProvider).rhythms, {'Fox'});
      expect(container.read(libraryViewSettingsProvider).page, 3);

      // Toca em limpar filtros no painel da biblioteca
      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();

      // Biblioteca foi limpa e voltou à página 1
      expect(container.read(libraryCatalogFiltersProvider).isEmpty, isTrue);
      expect(container.read(libraryViewSettingsProvider).page, 1);
      expect(prefs.getString(StorageKeys.libraryCatalogFilters), isNull);

      // Home continua intacta com seu filtro 'Dm'
      expect(container.read(homeCatalogFiltersProvider).tonalities, {'Dm'});
    },
  );
}
