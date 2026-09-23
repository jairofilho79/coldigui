import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/catalog_filter_sections.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  final index = catalogIndexOf([
    catalogGroup(
      praiseId: 'p1',
      name: 'Hino',
      tonality: 'Dm',
      rhythm: 'Fox',
      category: 'Clamor',
      tags: const ['PES · 9.2026'],
      pdfKinds: const {'k-grade': 'Grade'},
    ),
    catalogGroup(
      praiseId: 'p2',
      name: 'Coro',
      tonality: 'G',
      tags: const ['CIAs'],
      pdfKinds: const {'k-cifra1': 'Cifra I'},
    ),
  ]);

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Map<String, Object> prefsValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        coldigomSearchIndexProvider.overrideWithValue(index),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(
            body: SingleChildScrollView(child: CatalogFilterSections()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(FilterChip, label);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  bool isSelected(WidgetTester tester, String label) => tester
      .widget<FilterChip>(find.widgetWithText(FilterChip, label))
      .selected;

  testWidgets('secções e chips saem do índice local, com o pai das tags', (
    tester,
  ) async {
    await pump(tester);

    for (final label in [
      'Tom',
      'Ritmo',
      'Categoria',
      'Tags',
      'Materiais',
      'Dm',
      'G',
      'Fox',
      'Clamor',
      'PES',
      'PES · 9.2026',
      'CIAs',
      'Grade',
      'Cifra I',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('tocar num chip alterna o filtro', (tester) async {
    final container = await pump(tester);

    await tapChip(tester, 'Dm');
    expect(container.read(catalogFiltersProvider).tonalities, {'Dm'});
    expect(isSelected(tester, 'Dm'), isTrue);

    await tapChip(tester, 'Cifra I');
    expect(container.read(catalogFiltersProvider).materialKindIds, {
      'k-cifra1',
    });

    await tapChip(tester, 'Dm');
    expect(container.read(catalogFiltersProvider).tonalities, isEmpty);
  });

  testWidgets(
    'seleção que o catálogo não tem aparece marcada para poder desmarcar',
    (tester) async {
      final container = await pump(
        tester,
        prefsValues: {
          StorageKeys.catalogFilters: jsonEncode(
            const CatalogFilterState(
              tags: {'Sumida'},
              materialKindIds: {'k-velho'},
            ).toPersistedJson(),
          ),
        },
      );

      expect(isSelected(tester, 'Sumida'), isTrue);
      expect(isSelected(tester, 'k-velho'), isTrue);

      await tapChip(tester, 'Sumida');
      expect(container.read(catalogFiltersProvider).tags, isEmpty);
    },
  );
}
