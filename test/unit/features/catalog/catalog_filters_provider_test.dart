import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('estado inicial sem prefs é o default (todos materiais)', () {
    final container = createContainer();

    expect(
      container.read(catalogFiltersProvider).selectedMaterials,
      CatalogMaterials.defaultSelected.toSet(),
    );
    expect(container.read(catalogFiltersProvider).selectedArranjos, isEmpty);
  });

  test('toggleMaterial grava JSON em StorageKeys.catalogFilters', () {
    final container = createContainer();

    // O default já seleciona todos os materiais — alternar um remove-o.
    container
        .read(catalogFiltersProvider.notifier)
        .toggleMaterial(CatalogMaterials.partitura);

    final raw = prefs.getString(StorageKeys.catalogFilters);
    expect(raw, isNotNull);
    expect(raw, isNot(contains(CatalogMaterials.partitura)));
    expect(raw, contains(CatalogMaterials.gestosEmGravura));
    expect(
      container.read(catalogFiltersProvider).selectedMaterials,
      isNot(contains(CatalogMaterials.partitura)),
    );
  });

  test('novo container com o mesmo prefs relê o estado persistido', () {
    final first = createContainer();
    first
        .read(catalogFiltersProvider.notifier)
        .toggleMaterial(CatalogMaterials.partitura);
    final persisted = first.read(catalogFiltersProvider).selectedMaterials;

    final second = createContainer();

    expect(second.read(catalogFiltersProvider).selectedMaterials, persisted);
  });

  test('toggleArranjo também persiste', () {
    final first = createContainer();
    first.read(catalogFiltersProvider.notifier).toggleArranjo('ColAdultos');

    final second = createContainer();

    expect(second.read(catalogFiltersProvider).selectedArranjos, {
      'ColAdultos',
    });
  });

  test('hydrateFromUrl com filtro vence o gravado', () {
    final container = createContainer();
    container
        .read(catalogFiltersProvider.notifier)
        .toggleMaterial(CatalogMaterials.partitura);

    container
        .read(catalogFiltersProvider.notifier)
        .hydrateFromUrl(materiais: CatalogMaterials.cifra);

    expect(container.read(catalogFiltersProvider).selectedMaterials, {
      CatalogMaterials.cifra,
    });
  });

  test('hydrateFromUrl sem parâmetros preserva o estado gravado', () {
    final first = createContainer();
    first
        .read(catalogFiltersProvider.notifier)
        .toggleMaterial(CatalogMaterials.partitura);
    final persisted = first.read(catalogFiltersProvider).selectedMaterials;

    final second = createContainer();
    // Tanto HomeScreen quanto LibraryScreen chamam hydrateFromUrl no
    // primeiro build, mesmo sem query params (materiais/arranjo nulos) —
    // isso não pode apagar o que foi lido de SharedPreferences no build().
    second.read(catalogFiltersProvider.notifier).hydrateFromUrl();

    expect(second.read(catalogFiltersProvider).selectedMaterials, persisted);
  });

  test('reset() apaga a chave persistida e volta ao default', () {
    final container = createContainer();
    container
        .read(catalogFiltersProvider.notifier)
        .toggleMaterial(CatalogMaterials.partitura);
    expect(prefs.getString(StorageKeys.catalogFilters), isNotNull);

    container.read(catalogFiltersProvider.notifier).reset();

    expect(prefs.getString(StorageKeys.catalogFilters), isNull);
    expect(
      container.read(catalogFiltersProvider).selectedMaterials,
      CatalogMaterials.defaultSelected.toSet(),
    );

    final reread = createContainer();
    expect(
      reread.read(catalogFiltersProvider).selectedMaterials,
      CatalogMaterials.defaultSelected.toSet(),
    );
  });
}
