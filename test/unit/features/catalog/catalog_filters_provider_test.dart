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

  test('toggles gravam o formato v2 e um container novo relê', () async {
    await setUpPrefs();
    final first = createContainer();
    first.read(catalogFiltersProvider.notifier)
      ..toggleTonality('Dm')
      ..toggleRhythm('Fox')
      ..toggleCategory('Clamor')
      ..toggleTag('PES')
      ..toggleMaterialKind('k1');

    final raw = jsonDecode(
      prefs.getString(StorageKeys.catalogFilters)!,
    ) as Map<String, dynamic>;
    expect(raw['v'], 2);
    expect(raw['tags'], ['PES']);
    expect(
      createContainer().read(catalogFiltersProvider),
      const CatalogFilterState(
        tonalities: {'Dm'},
        rhythms: {'Fox'},
        categories: {'Clamor'},
        tags: {'PES'},
        materialKindIds: {'k1'},
      ),
    );
  });

  test('tocar duas vezes desmarca', () async {
    await setUpPrefs();
    final container = createContainer();
    container.read(catalogFiltersProvider.notifier)
      ..toggleTag('PES')
      ..toggleTag('PES');

    expect(container.read(catalogFiltersProvider).isEmpty, isTrue);
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

  test(
    'mexer num filtro volta a /biblioteca à página 1; hidratar da URL não',
    () async {
      await setUpPrefs();
      final container = createContainer();
      container.read(libraryViewSettingsProvider.notifier).setPage(3);

      container
          .read(catalogFiltersProvider.notifier)
          .hydrateFromUrl(tags: 'PES');
      expect(container.read(libraryViewSettingsProvider).page, 3);

      container.read(catalogFiltersProvider.notifier).toggleTag('CIAs');
      expect(container.read(libraryViewSettingsProvider).page, 1);
    },
  );

  test('clear esvazia, apaga a pref e volta à página 1', () async {
    await setUpPrefs();
    final container = createContainer();
    container.read(catalogFiltersProvider.notifier).toggleTag('PES');
    container.read(libraryViewSettingsProvider.notifier).setPage(2);

    container.read(catalogFiltersProvider.notifier).clear();

    expect(container.read(catalogFiltersProvider).isEmpty, isTrue);
    expect(container.read(libraryViewSettingsProvider).page, 1);
    await pumpEventQueue();
    expect(prefs.getString(StorageKeys.catalogFilters), isNull);
  });
}
