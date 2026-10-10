import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  Future<void> setUpPrefs([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
  }

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('sem pref: nenhum filtro', () async {
    await setUpPrefs();
    expect(
      createContainer().read(catalogFiltersProvider),
      CatalogFilterState.empty,
    );
  });

  test('toggles gravam o formato v3 e um container novo relê', () async {
    await setUpPrefs();
    final first = createContainer();
    first.read(catalogFiltersProvider.notifier)
      ..toggleTonality('Dm')
      ..toggleRhythm('Fox')
      ..toggleTag('PES')
      ..toggleMaterialKind('k1');

    final raw = jsonDecode(
      prefs.getString(StorageKeys.catalogFilters)!,
    ) as Map<String, dynamic>;
    expect(raw['v'], 3);
    expect(raw, isNot(contains('categories')));
    expect(raw['tags'], ['PES']);
    expect(
      createContainer().read(catalogFiltersProvider),
      const CatalogFilterState(
        tonalities: {'Dm'},
        rhythms: {'Fox'},
        tags: {'PES'},
        materialKindIds: {'k1'},
      ),
    );
  });

  test(
    'pref v2 com categories é migrada para tags, não descartada nem apagada',
    () async {
      await setUpPrefs({
        StorageKeys.catalogFilters: jsonEncode({
          'v': 2,
          'tonalities': ['Dm'],
          'rhythms': <String>[],
          'categories': ['Clamor', 'Avulsos'],
          'tags': ['PES'],
          'materialKinds': <String>[],
        }),
      });

      final container = createContainer();

      expect(
        container.read(catalogFiltersProvider),
        const CatalogFilterState(
          tonalities: {'Dm'},
          tags: {'PES', 'Coletânea', 'Coletânea · Clamor'},
        ),
      );
      await pumpEventQueue();
      expect(prefs.getString(StorageKeys.catalogFilters), isNotNull);

      // O próximo toggle grava a v3, já sem categories.
      container.read(catalogFiltersProvider.notifier).toggleRhythm('Fox');
      final raw = jsonDecode(
        prefs.getString(StorageKeys.catalogFilters)!,
      ) as Map<String, dynamic>;
      expect(raw['v'], 3);
      expect(raw, isNot(contains('categories')));
      expect(raw['tags'], ['Coletânea', 'Coletânea · Clamor', 'PES']);
    },
  );

  test('tocar duas vezes desmarca', () async {
    await setUpPrefs();
    final container = createContainer();
    container.read(catalogFiltersProvider.notifier)
      ..toggleTag('PES')
      ..toggleTag('PES');

    expect(container.read(catalogFiltersProvider).isEmpty, isTrue);
  });

  test('desmarcar a tag pai desmarca as subtags dela', () async {
    await setUpPrefs();
    final container = createContainer();
    container.read(catalogFiltersProvider.notifier)
      ..toggleTag('PES')
      ..toggleTag('PES · 9.2026')
      ..toggleTag('PES · 9.2026 · Coro')
      ..toggleTag('PESCA')
      ..toggleTag('PES');

    expect(container.read(catalogFiltersProvider).tags, {'PESCA'});
  });

  test(
    'pref no formato antigo {materials, arranjos} é descartada e apagada',
    () async {
      await setUpPrefs({
        StorageKeys.catalogFilters: jsonEncode({
          'materials': ['Partitura'],
          'arranjos': ['ColAdultos'],
        }),
      });

      final container = createContainer();

      expect(container.read(catalogFiltersProvider), CatalogFilterState.empty);
      await pumpEventQueue();
      expect(prefs.getString(StorageKeys.catalogFilters), isNull);
    },
  );

  test('pref ilegível também é descartada', () async {
    await setUpPrefs({StorageKeys.catalogFilters: 'não é json'});

    expect(
      createContainer().read(catalogFiltersProvider),
      CatalogFilterState.empty,
    );
  });

  test(
    'hydrateFromUrl com params substitui os cinco; sem params mantém o gravado',
    () async {
      await setUpPrefs();
      final container = createContainer();
      final notifier = container.read(catalogFiltersProvider.notifier)
        ..toggleTonality('Dm');

      notifier.hydrateFromUrl();
      expect(container.read(catalogFiltersProvider).tonalities, {'Dm'});

      notifier.hydrateFromUrl(tags: 'PES,CIAs', materialKinds: 'k1');
      expect(
        container.read(catalogFiltersProvider),
        const CatalogFilterState(
          tags: {'PES', 'CIAs'},
          materialKindIds: {'k1'},
        ),
      );
    },
  );

  test('mexer num filtro da biblioteca volta à página 1; da tela inicial não mexe na biblioteca', () async {
    await setUpPrefs();
    final container = createContainer();
    container.read(libraryViewSettingsProvider.notifier).setPage(3);

    container.read(catalogFiltersProvider.notifier).toggleTag('CIAs');
    expect(container.read(libraryViewSettingsProvider).page, 3);

    container
        .read(libraryCatalogFiltersProvider.notifier)
        .hydrateFromUrl(tags: 'PES');
    expect(container.read(libraryViewSettingsProvider).page, 3);

    container.read(libraryCatalogFiltersProvider.notifier).toggleTag('CIAs');
    expect(container.read(libraryViewSettingsProvider).page, 1);
  });

  test(
    'clear na biblioteca esvazia, apaga a pref e volta à página 1',
    () async {
      await setUpPrefs();
      final container = createContainer();
      container.read(libraryCatalogFiltersProvider.notifier).toggleTag('PES');
      container.read(libraryViewSettingsProvider.notifier).setPage(2);

      container.read(libraryCatalogFiltersProvider.notifier).clear();

      expect(container.read(libraryCatalogFiltersProvider).isEmpty, isTrue);
      expect(container.read(libraryViewSettingsProvider).page, 1);
      await pumpEventQueue();
      expect(prefs.getString(StorageKeys.libraryCatalogFilters), isNull);
    },
  );

  test('homeCatalogFiltersProvider e libraryCatalogFiltersProvider têm estados e prefs independentes', () async {
    await setUpPrefs();
    final container = createContainer();

    container.read(homeCatalogFiltersProvider.notifier).toggleTag('PES');
    container.read(libraryCatalogFiltersProvider.notifier).toggleTonality('Dm');

    expect(container.read(homeCatalogFiltersProvider).tags, {'PES'});
    expect(container.read(homeCatalogFiltersProvider).tonalities, isEmpty);

    expect(container.read(libraryCatalogFiltersProvider).tags, isEmpty);
    expect(container.read(libraryCatalogFiltersProvider).tonalities, {'Dm'});

    await pumpEventQueue();
    expect(prefs.getString(StorageKeys.catalogFilters), contains('PES'));
    expect(prefs.getString(StorageKeys.catalogFilters), isNot(contains('Dm')));
    expect(prefs.getString(StorageKeys.libraryCatalogFilters), contains('Dm'));
    expect(
      prefs.getString(StorageKeys.libraryCatalogFilters),
      isNot(contains('PES')),
    );
  });

  test('hydrateFromUrl converte category legado em subtag', () async {
    await setUpPrefs();
    final container = createContainer();

    container
        .read(catalogFiltersProvider.notifier)
        .hydrateFromUrl(category: 'Clamor', tonality: 'Dm');

    expect(
      container.read(catalogFiltersProvider),
      const CatalogFilterState(
        tonalities: {'Dm'},
        tags: {'Coletânea', 'Coletânea · Clamor'},
      ),
    );
  });

  test(
    'link só com categoria descartada (Avulsos) mantém o gravado (D2)',
    () async {
      await setUpPrefs();
      final container = createContainer();
      final notifier = container.read(catalogFiltersProvider.notifier)
        ..toggleTag('PES');

      notifier.hydrateFromUrl(category: 'Avulsos');

      expect(
        container.read(catalogFiltersProvider),
        const CatalogFilterState(tags: {'PES'}),
      );
    },
  );

  test('toggleMaterialKind segue a regra de família da taxonomia', () async {
    await setUpPrefs({
      StorageKeys.coldigomKindTaxonomy: jsonEncode({
        'kindClasses': [],
        'kinds': [
          {'id': 'sax', 'name': 'Saxofone'},
          {'id': 'alto', 'name': 'Saxofone alto', 'parent': 'sax'},
        ],
      }),
    });
    final container = createContainer();
    final notifier = container.read(catalogFiltersProvider.notifier);

    notifier.toggleMaterialKind('alto');
    notifier.toggleMaterialKind('sax');
    expect(container.read(catalogFiltersProvider).materialKindIds, {'sax'});

    notifier.toggleMaterialKind('alto');
    expect(container.read(catalogFiltersProvider).materialKindIds, {
      'sax',
      'alto',
    });

    notifier.toggleMaterialKind('sax');
    expect(container.read(catalogFiltersProvider).materialKindIds, isEmpty);
  });
}
