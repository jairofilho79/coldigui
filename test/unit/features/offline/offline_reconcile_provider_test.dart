import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/offline/data/datasources/offline_available_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/entities/reconcile_result.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/migrate_offline_storage.dart';
import 'package:coldigui/features/offline/domain/usecases/reconcile_offline_index.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_reconcile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_test_helpers.dart';

class _CountingMigrate extends MigrateOfflineStorage {
  _CountingMigrate(
    super.prefs,
    super.local,
    super.offlineAvailableStore,
  );

  int callCount = 0;

  @override
  Future<void> call() async {
    callCount++;
  }
}

class _CountingReconcile extends ReconcileOfflineIndex {
  _CountingReconcile(super.repository, super.store);

  int callCount = 0;

  @override
  Future<ReconcileResult> call({
    materialPackage,
    materialCategory,
  }) async {
    callCount++;
    return const ReconcileResult(removedFromIndex: 0, orphanFiles: 0);
  }
}

class _StubRepo implements OfflinePdfRepository {
  @override
  Future<Map<String, int>> countByCategory() async => {};

  @override
  Future<void> clearAll() async {}

  @override
  Future<OfflinePdfEntry?> findIndexEntry(String pdfId) async => null;

  @override
  Future<void> indexExtractedBatch(List<ExtractedPdfItem> items) async {}

  @override
  Future<List<OfflinePdfEntry>> listAll() async => [];

  @override
  Future<OfflinePdfEntry?> lookup(String pdfId) async => null;

  @override
  Future<(OfflinePdfEntry? entry, bool hasIndexEntry)> lookupWithIndexState(
    String pdfId,
  ) async =>
      (null, false);

  @override
  Future<Set<String>> lookupBatch(Set<String> pdfIds) async => {};

  @override
  Future<void> remove(String pdfId) async {}

  @override
  Future<String?> findPdfIdByAbsolutePath(String absolutePath) async => null;

  @override
  Future<int> removeIndexEntries(Set<String> pdfIds) async => 0;

  @override
  Future<OfflinePdfEntry> upsert({
    required String pdfId,
    required Uint8List bytes,
    required String category,
    bool isPersistent = false,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> upsertBatch(List<OfflinePdfBatchItem> items) async {}

  @override
  Future<int> totalCachedBytes() async => 0;

  @override
  Future<int> evictOldestPdfs({
    required int targetBytes,
    Set<String> excludePdfIds = const {},
  }) async =>
      0;

  @override
  Future<void> flushPendingTouchLastAccessed() async {}
}

void main() {
  late SharedPreferences prefs;
  late Isar isar;
  late Directory isarDir;
  late _CountingMigrate migrate;
  late _CountingReconcile reconcile;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    isarDir = await Directory.systemTemp.createTemp('reconcile_migrate_');
    isar = await openOfflineTestIsar(isarDir);
    migrate = _CountingMigrate(
      prefs,
      OfflinePdfLocalDatasource(isar),
      OfflineAvailableStore(prefs),
    );
    reconcile = _CountingReconcile(
      _StubRepo(),
      PdfLocalStore(
        getApplicationDocumentsDirectory: () async =>
            Directory.systemTemp.createTempSync('reconcile_test_'),
      ),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        migrateOfflineStorageProvider.overrideWith((ref) => migrate),
        reconcileOfflineIndexProvider.overrideWith((ref) => reconcile),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('primeiro reconcile após cold start executa', () async {
    final container = createContainer();

    await container.read(offlineReconcileProvider.notifier).requestReconcile();

    expect(migrate.callCount, 1);
    expect(reconcile.callCount, 1);
    expect(container.read(offlineReconcileProvider).lastRunAt, isNotNull);
    expect(prefs.getInt(StorageKeys.lastReconcileAt), isNotNull);
  });

  test('reconcile recente (< 30 min) é ignorado', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.lastReconcileAt: DateTime.now()
          .subtract(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
    });
    prefs = await SharedPreferences.getInstance();
    migrate = _CountingMigrate(
      prefs,
      OfflinePdfLocalDatasource(isar),
      OfflineAvailableStore(prefs),
    );
    reconcile = _CountingReconcile(
      _StubRepo(),
      PdfLocalStore(
        getApplicationDocumentsDirectory: () async =>
            Directory.systemTemp.createTempSync('reconcile_test_'),
      ),
    );

    final container = createContainer();

    await container.read(offlineReconcileProvider.notifier).requestReconcile();

    expect(migrate.callCount, 0);
    expect(reconcile.callCount, 0);
    expect(container.read(offlineReconcileProvider).lastRunAt, isNull);
  });

  test('reconcile após 30 min executa novamente', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.lastReconcileAt: DateTime.now()
          .subtract(const Duration(minutes: 31))
          .millisecondsSinceEpoch,
    });
    prefs = await SharedPreferences.getInstance();
    migrate = _CountingMigrate(
      prefs,
      OfflinePdfLocalDatasource(isar),
      OfflineAvailableStore(prefs),
    );
    reconcile = _CountingReconcile(
      _StubRepo(),
      PdfLocalStore(
        getApplicationDocumentsDirectory: () async =>
            Directory.systemTemp.createTempSync('reconcile_test_'),
      ),
    );

    final container = createContainer();

    await container.read(offlineReconcileProvider.notifier).requestReconcile();

    expect(migrate.callCount, 1);
    expect(reconcile.callCount, 1);
    expect(container.read(offlineReconcileProvider).lastRunAt, isNotNull);
  });
}
