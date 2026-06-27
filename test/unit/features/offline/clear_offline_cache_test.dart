import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart';
import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/offline/data/datasources/offline_available_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_bulk_categories_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_bulk_checkpoint_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_selected_categories_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/entities/offline_bulk_checkpoint.dart';
import 'package:coldigui/features/offline/domain/usecases/clear_offline_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_test_helpers.dart';

class _StubCatalogLocal extends CatalogLocalDatasource {
  _StubCatalogLocal() : super(_FakeIsar());

  @override
  Future<Map<String, String>> loadPdfIdToCategoriaMap() async => const {};
}

// Isar não é usado pelo stub — apenas satisfaz o construtor.
class _FakeIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late PdfLocalStore store;
  late OfflinePdfRepositoryImpl repository;
  late SharedPreferences prefs;
  late OfflineBulkCheckpointStore checkpointStore;
  late OfflineBulkCategoriesStore bulkCategoriesStore;
  late OfflineSelectedCategoriesStore selectedCategoriesStore;
  late OfflineAvailableStore offlineAvailableStore;
  late ClearOfflineCache useCase;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clear_offline_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = await openOfflineTestIsar(tempDir);
    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: store,
      local: OfflinePdfLocalDatasource(isar),
    );
    prefs = await SharedPreferences.getInstance();
    checkpointStore = OfflineBulkCheckpointStore(prefs);
    bulkCategoriesStore = OfflineBulkCategoriesStore(prefs);
    selectedCategoriesStore = OfflineSelectedCategoriesStore(prefs);
    offlineAvailableStore = OfflineAvailableStore(prefs);
    useCase = ClearOfflineCache(
      repository,
      _StubCatalogLocal(),
      store,
      checkpointStore,
      bulkCategoriesStore,
      selectedCategoriesStore,
      offlineAvailableStore,
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('limpa índice, diretório PDFs, checkpoint bulk e flag offline',
      () async {
    await repository.upsert(
      pdfId: encodePdfId('ColAdultos/a.pdf'),
      bytes: Uint8List.fromList([1]),
      category: CatalogMaterials.partitura,
    );

    await offlineAvailableStore.markConfigured();
    await bulkCategoriesStore.addCategories([CatalogMaterials.partitura]);
    await selectedCategoriesStore.save({CatalogMaterials.partitura});
    await checkpointStore.save(
      OfflineBulkCheckpoint(
        categories: const [CatalogMaterials.partitura],
        categoryIndex: 0,
        partIndex: 0,
        extractedPdfCount: 0,
        startedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final rootBefore = await store.rootDirectory;
    expect(await rootBefore.list(recursive: true).length, greaterThan(0));

    final wasFullClear = await useCase(
      materials: {CatalogMaterials.partitura},
    );

    expect(wasFullClear, isTrue);
    expect((await repository.listAll()).length, 0);
    final rootAfter = await store.rootDirectory;
    expect(await rootAfter.list().length, 0);
    expect(await checkpointStore.load(), isNull);
    expect(bulkCategoriesStore.load(), isEmpty);
    expect(prefs.getString(StorageKeys.offlineBulkCategories), isNull);
    expect(prefs.getString(StorageKeys.offlineSelectedCategories), isNull);
    expect(prefs.getString(StorageKeys.offlineAvailable),
        OfflineAvailableStore.disabledValue);
  });

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

    final wasFullClear = await useCase(
      materials: {CatalogMaterials.partitura},
    );

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
