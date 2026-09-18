import '../../../support/fakes/fake_isar.dart';
import 'dart:io';
import 'dart:typed_data';
import 'offline_test_helpers.dart';
import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart';
import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/offline/data/datasources/offline_available_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_bulk_categories_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/offline_selected_categories_store.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/usecases/clear_offline_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubCatalogLocal extends CatalogLocalDatasource {
  _StubCatalogLocal() : super(FakeIsar());

  @override
  Future<Map<String, String>> loadPdfIdToCategoriaMap() async => const {};
}

// Isar não é usado pelo stub — apenas satisfaz o construtor.
void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late PdfLocalStore store;
  late OfflinePdfRepositoryImpl repository;
  late SharedPreferences prefs;
  late OfflineBulkCategoriesStore bulkCategoriesStore;
  late OfflineSelectedCategoriesStore selectedCategoriesStore;
  late OfflineAvailableStore offlineAvailableStore;
  late ClearOfflineCache useCase;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clear_offline_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = openOfflineTestIsar(tempDir);
    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: pdfStoragePortFor(store),
      local: OfflinePdfLocalDatasource(isar),
    );
    prefs = await SharedPreferences.getInstance();
    bulkCategoriesStore = OfflineBulkCategoriesStore(prefs);
    selectedCategoriesStore = OfflineSelectedCategoriesStore(prefs);
    offlineAvailableStore = OfflineAvailableStore(prefs);
    useCase = ClearOfflineCache(
      repository,
      _StubCatalogLocal(),
      pdfStoragePortFor(store),
      bulkCategoriesStore,
      selectedCategoriesStore,
      offlineAvailableStore,
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'limpa índice, diretório PDFs, categorias bulk e flag offline',
    () async {
      await repository.upsert(
        pdfId: encodePdfId('ColAdultos/a.pdf'),
        bytes: Uint8List.fromList([1]),
        category: CatalogMaterials.partitura,
      );

      await offlineAvailableStore.markConfigured();
      await bulkCategoriesStore.addCategories([CatalogMaterials.partitura]);
      await selectedCategoriesStore.save({CatalogMaterials.partitura});
      // Instalação antiga: blob do checkpoint do bulk ZIP (pipeline removido).
      await prefs.setString(StorageKeys.offlineBulkCheckpoint, '{"done":1}');

      final rootBefore = await store.rootDirectory;
      expect(await rootBefore.list(recursive: true).length, greaterThan(0));

      final wasFullClear = await useCase(
        materials: {CatalogMaterials.partitura},
      );

      expect(wasFullClear, isTrue);
      expect((await repository.listAll()).length, 0);
      final rootAfter = await store.rootDirectory;
      expect(await rootAfter.list().length, 0);
      expect(bulkCategoriesStore.load(), isEmpty);
      expect(prefs.getString(StorageKeys.offlineBulkCategories), isNull);
      expect(prefs.getString(StorageKeys.offlineBulkCheckpoint), isNull);
      expect(prefs.getString(StorageKeys.offlineSelectedCategories), isNull);
      expect(
        prefs.getString(StorageKeys.offlineAvailable),
        OfflineAvailableStore.disabledValue,
      );
    },
  );

  test('limpeza parcial remove só materiais selecionados', () async {
    await repository.upsert(
      pdfId: encodePdfId('partitura/a.pdf'),
      bytes: Uint8List.fromList([1]),
      category: CatalogMaterials.partitura,
    );
    await repository.upsert(
      pdfId: encodePdfId('cifra/a.pdf'),
      bytes: Uint8List.fromList([2]),
      category: CatalogMaterials.cifraNivelI,
    );

    await offlineAvailableStore.markConfigured();
    await bulkCategoriesStore.addCategories(CatalogMaterials.uiMaterials);

    final wasFullClear = await useCase(materials: {CatalogMaterials.partitura});

    expect(wasFullClear, isFalse);
    final remaining = await repository.listAll();
    expect(remaining.length, 1);
    expect(remaining.single.category, CatalogMaterials.cifraNivelI);
    expect(bulkCategoriesStore.load(), {
      CatalogMaterials.cifra,
      CatalogMaterials.gestosEmGravura,
    });
    expect(
      prefs.getString(StorageKeys.offlineAvailable),
      isNot(OfflineAvailableStore.disabledValue),
    );
    expect(prefs.getString(StorageKeys.offlineSelectedCategories), isNull);
  });
}
