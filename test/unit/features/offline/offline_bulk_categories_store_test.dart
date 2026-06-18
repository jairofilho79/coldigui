import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/offline/data/datasources/offline_bulk_categories_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('addCategories persiste união ordenada por uiMaterials', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineBulkCategoriesStore(prefs);

    final merged = await store.addCategories([CatalogMaterials.partitura]);
    expect(merged, {CatalogMaterials.partitura});

    final merged2 = await store.addCategories([CatalogMaterials.cifra]);
    expect(merged2, {CatalogMaterials.partitura, CatalogMaterials.cifra});
    expect(store.load(), merged2);
  });

  test('clear remove categorias persistidas', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineBulkCategoriesStore(prefs);

    await store.addCategories(CatalogMaterials.uiMaterials);
    await store.clear();

    expect(store.load(), isEmpty);
    expect(prefs.getString(StorageKeys.offlineBulkCategories), isNull);
  });

  test('loadOrMigrate infere categorias com PDFs baixados', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineBulkCategoriesStore(prefs);

    final migrated = await store.loadOrMigrate(
      isConfigured: true,
      byCategory: {
        CatalogMaterials.partitura: 10,
        CatalogMaterials.cifra: 0,
        CatalogMaterials.gestosEmGravura: 0,
      },
    );

    expect(migrated, {CatalogMaterials.partitura});
    expect(store.load(), {CatalogMaterials.partitura});
  });

  test('loadOrMigrate não infere quando não configurado', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineBulkCategoriesStore(prefs);

    final migrated = await store.loadOrMigrate(
      isConfigured: false,
      byCategory: {CatalogMaterials.partitura: 10},
    );

    expect(migrated, isEmpty);
  });
}
