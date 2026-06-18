import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/offline/data/datasources/offline_selected_categories_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load retorna defaultSelected quando vazio', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineSelectedCategoriesStore(prefs);

    expect(store.load(), CatalogMaterials.defaultSelected);
  });

  test('save e load persistem seleção', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineSelectedCategoriesStore(prefs);

    await store.save({CatalogMaterials.partitura});
    expect(store.load(), {CatalogMaterials.partitura});
    expect(
      prefs.getString(StorageKeys.offlineSelectedCategories),
      isNotNull,
    );
  });

  test('clear restaura default no próximo load', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineSelectedCategoriesStore(prefs);

    await store.save({CatalogMaterials.cifra});
    await store.clear();
    expect(store.load(), CatalogMaterials.defaultSelected);
  });
}
