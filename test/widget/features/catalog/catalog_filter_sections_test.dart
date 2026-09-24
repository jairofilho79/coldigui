import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/catalog_filter_sections.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_kind_chips.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  final defaultIndex = catalogIndexOf([
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
    ColdigomSearchIndex? index,
    MaterialKindTaxonomy? taxonomy,
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        coldigomSearchIndexProvider.overrideWithValue(index ?? defaultIndex),
        if (taxonomy != null)
          coldigomKindTaxonomyProvider.overrideWithValue(taxonomy),
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

  final metaisIndex = catalogIndexOf([
    catalogGroup(
      praiseId: 'm1',
      name: 'Marcha',
      pdfKinds: const {
        'sax': 'Saxofone',
        'alto': 'Saxofone alto',
        'tenor': 'Saxofone tenor',
        'grade': 'Grade',
      },
      audioKinds: const {'play': 'Playback'},
    ),
  ]);
  final metais = MaterialKindTaxonomy(
    classes: const [MaterialKindClass(id: 'metais', label: 'Metais')],
    kinds: const {
      'sax': MaterialKindTaxon(name: 'Saxofone', classId: 'metais', order: 30),
      'alto': MaterialKindTaxon(
        name: 'Saxofone alto',
        classId: 'metais',
        parentId: 'sax',
        order: 50,
      ),
      'tenor': MaterialKindTaxon(
        name: 'Saxofone tenor',
        classId: 'metais',
        parentId: 'sax',
        order: 60,
      ),
    },
  );

  Finder family(String label) =>
      find.widgetWithText(MaterialKindFamilyChip, label);

  testWidgets('classe com rótulo, família recolhida, Outros por último', (
    tester,
  ) async {
    await pump(tester, index: metaisIndex, taxonomy: metais);

    expect(find.text('METAIS'), findsOneWidget);
    expect(find.text('OUTROS'), findsOneWidget);
    expect(family('Saxofone'), findsOneWidget);
    expect(find.text('Saxofone alto'), findsNothing);
    expect(
      tester.getTopLeft(find.text('METAIS')).dy,
      lessThan(tester.getTopLeft(find.text('OUTROS')).dy),
    );
  });

  testWidgets(
    'marcar a família inclui as variantes; tocar numa refina; desmarcar o pai limpa',
    (tester) async {
      final container = await pump(
        tester,
        index: metaisIndex,
        taxonomy: metais,
      );

      await tester.tap(find.text('Saxofone'));
      await tester.pumpAndSettle();
      expect(container.read(catalogFiltersProvider).materialKindIds, {'sax'});

      await tester.tap(find.byTooltip('Ver variantes de Saxofone'));
      await tester.pumpAndSettle();
      final alto = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Saxofone alto'),
      );
      expect(
        alto.shape,
        isA<DashedRoundedRectangleBorder>(),
        reason: 'incluído',
      );

      await tapChip(tester, 'Saxofone tenor');
      expect(container.read(catalogFiltersProvider).materialKindIds, {
        'sax',
        'tenor',
      });
      expect(isSelected(tester, 'Saxofone tenor'), isTrue);

      await tester.tap(find.text('Saxofone'));
      await tester.pumpAndSettle();
      expect(container.read(catalogFiltersProvider).materialKindIds, isEmpty);
    },
  );

  testWidgets('chip de Tipo esconde kinds, mostra a dica e «Todos» volta', (
    tester,
  ) async {
    await pump(tester, index: metaisIndex, taxonomy: metais);

    await tapChip(tester, 'Áudio');
    expect(find.text('Playback'), findsOneWidget);
    expect(family('Saxofone'), findsNothing);
    expect(find.text('4 materiais ocultos pelo tipo'), findsOneWidget);

    await tapChip(tester, 'Todos');
    expect(family('Saxofone'), findsOneWidget);
    expect(find.textContaining('ocultos pelo tipo'), findsNothing);
  });

  testWidgets(
    'tipo escondendo tudo que é classificado mantém o rótulo Outros',
    (tester) async {
      await pump(tester, index: metaisIndex, taxonomy: metais);

      await tapChip(tester, 'Áudio');
      expect(find.text('Playback'), findsOneWidget);
      expect(family('Saxofone'), findsNothing);
      expect(find.text('OUTROS'), findsOneWidget);
    },
  );

  testWidgets('selecionado fora do tipo continua visível', (tester) async {
    await pump(tester, index: metaisIndex, taxonomy: metais);

    await tapChip(tester, 'Grade');
    await tapChip(tester, 'Áudio');
    expect(find.widgetWithText(FilterChip, 'Grade'), findsOneWidget);
  });

  testWidgets('sem taxonomia a lista fica plana, sem o rótulo Outros', (
    tester,
  ) async {
    await pump(tester, index: metaisIndex);

    expect(find.text('OUTROS'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Saxofone alto'), findsOneWidget);
  });

  testWidgets('secções e chips saem do índice local; tags só as raízes', (
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
      'CIAs',
      'Grade',
      'Cifra I',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Subtags'), findsNothing);
    expect(find.text('9.2026'), findsNothing);
  });

  testWidgets('selecionar a tag pai mostra as subtags; desmarcar esconde', (
    tester,
  ) async {
    final container = await pump(tester);

    await tapChip(tester, 'CIAs');
    expect(find.text('Subtags'), findsNothing, reason: 'CIAs não tem filhas');

    await tapChip(tester, 'PES');
    expect(find.text('Subtags'), findsOneWidget);
    expect(isSelected(tester, '9.2026'), isFalse);

    await tapChip(tester, '9.2026');
    expect(container.read(catalogFiltersProvider).tags, {
      'CIAs',
      'PES',
      'PES · 9.2026',
    });

    await tapChip(tester, 'PES');
    expect(container.read(catalogFiltersProvider).tags, {'CIAs'});
    expect(find.text('Subtags'), findsNothing);
    expect(find.text('9.2026'), findsNothing);
  });

  testWidgets('subtag selecionada sem o pai continua visível para desmarcar', (
    tester,
  ) async {
    final container = await pump(
      tester,
      prefsValues: {
        StorageKeys.catalogFilters: jsonEncode(
          const CatalogFilterState(tags: {'PES · 9.2026'}).toPersistedJson(),
        ),
      },
    );

    expect(find.text('Subtags'), findsOneWidget);
    expect(isSelected(tester, '9.2026'), isTrue);
    expect(isSelected(tester, 'PES'), isFalse);

    await tapChip(tester, '9.2026');
    expect(container.read(catalogFiltersProvider).tags, isEmpty);
    expect(find.text('Subtags'), findsNothing);
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
