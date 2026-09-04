import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/offline/data/datasources/offline_available_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/entities/offline_manifest.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/migrate_offline_storage.dart';
import 'package:coldigui/features/offline/domain/usecases/reconcile_offline_index.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_maintenance_lock_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_reconcile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_test_helpers.dart';

class _CountingMigrate extends MigrateOfflineStorage {
  _CountingMigrate(
    super.prefs,
    super.local,
    super.offlineAvailableStore,
    super.store,
  );

  int callCount = 0;
  bool throwStorageUnavailable = false;

  @override
  Future<void> call() async {
    if (throwStorageUnavailable) {
      throw const StorageUnavailableException('offline.clearAll');
    }
    callCount++;
  }
}

class _CountingReconcile extends ReconcileOfflineIndex {
  _CountingReconcile(super.repository, super.store);

  int callCount = 0;
  bool? lastIsIndexAvailable;
  OfflineMaterialPackage? lastPackage;

  @override
  Future<ReconcileOutcome> call({
    OfflineMaterialPackage? materialPackage,
    String? materialCategory,
    bool isIndexAvailable = true,
  }) async {
    callCount++;
    lastIsIndexAvailable = isIndexAvailable;
    lastPackage = materialPackage;
    return const ReconcileDone(
      removedFromIndex: 0,
      orphanFiles: 0,
      keptFiles: 0,
    );
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
  ) async => (null, false);

  @override
  Future<Set<String>> lookupBatch(Set<String> pdfIds) async => {};

  @override
  Future<void> remove(String pdfId) async {}

  @override
  Future<void> remapPdfId({
    required String fromPdfId,
    required String toPdfId,
  }) async {}

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
  }) async => throw UnimplementedError();

  @override
  Future<void> upsertBatch(List<OfflinePdfBatchItem> items) async {}

  @override
  Future<int> totalCachedBytes() async => 0;

  @override
  Future<int> evictOldestPdfs({
    required int targetBytes,
    Set<String> excludePdfIds = const {},
  }) async => 0;

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
    isar = openOfflineTestIsar(isarDir);
    migrate = _CountingMigrate(
      prefs,
      OfflinePdfLocalDatasource(isar),
      OfflineAvailableStore(prefs),
      pdfStoragePortFor(
        PdfLocalStore(
          getApplicationDocumentsDirectory: () async =>
              Directory.systemTemp.createTempSync('reconcile_migrate_store_'),
        ),
      ),
    );
    reconcile = _CountingReconcile(
      _StubRepo(),
      pdfStoragePortFor(
        PdfLocalStore(
          getApplicationDocumentsDirectory: () async =>
              Directory.systemTemp.createTempSync('reconcile_test_'),
        ),
      ),
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
  });

  ProviderContainer createContainer({bool isarAvailable = true}) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        migrateOfflineStorageProvider.overrideWith((ref) => migrate),
        reconcileOfflineIndexProvider.overrideWith((ref) => reconcile),
        isarAvailableProvider.overrideWithValue(isarAvailable),
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
      pdfStoragePortFor(
        PdfLocalStore(
          getApplicationDocumentsDirectory: () async =>
              Directory.systemTemp.createTempSync('reconcile_migrate_store_'),
        ),
      ),
    );
    reconcile = _CountingReconcile(
      _StubRepo(),
      pdfStoragePortFor(
        PdfLocalStore(
          getApplicationDocumentsDirectory: () async =>
              Directory.systemTemp.createTempSync('reconcile_test_'),
        ),
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
      pdfStoragePortFor(
        PdfLocalStore(
          getApplicationDocumentsDirectory: () async =>
              Directory.systemTemp.createTempSync('reconcile_migrate_store_'),
        ),
      ),
    );
    reconcile = _CountingReconcile(
      _StubRepo(),
      pdfStoragePortFor(
        PdfLocalStore(
          getApplicationDocumentsDirectory: () async =>
              Directory.systemTemp.createTempSync('reconcile_test_'),
        ),
      ),
    );

    final container = createContainer();

    await container.read(offlineReconcileProvider.notifier).requestReconcile();

    expect(migrate.callCount, 1);
    expect(reconcile.callCount, 1);
    expect(container.read(offlineReconcileProvider).lastRunAt, isNotNull);
  });

  test('reconcile repassa isIndexAvailable do isarAvailableProvider', () async {
    final container = createContainer(isarAvailable: false);

    await container.read(offlineReconcileProvider.notifier).requestReconcile();

    expect(reconcile.lastIsIndexAvailable, isFalse);
  });

  test('lock ocupado por outro dono não chama o usecase', () async {
    final container = createContainer();
    container
        .read(offlineMaintenanceLockProvider.notifier)
        .tryAcquire(OfflineMaintenanceOwner.bulk);

    await container.read(offlineReconcileProvider.notifier).requestReconcile();

    expect(migrate.callCount, 0);
    expect(reconcile.callCount, 0);
    expect(
      container.read(offlineReconcileProvider).lastSkipReason,
      ReconcileSkipReason.locked,
    );
    expect(prefs.getInt(StorageKeys.lastReconcileAt), isNull);
  });

  test('reconcile libera o lock ao terminar', () async {
    final container = createContainer();

    await container.read(offlineReconcileProvider.notifier).requestReconcile();

    expect(container.read(offlineMaintenanceLockProvider), isNull);
  });

  test(
    'reconcile escopado ignora o throttle e não persiste timestamp',
    () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.lastReconcileAt: DateTime.now().millisecondsSinceEpoch,
      });
      prefs = await SharedPreferences.getInstance();

      final container = createContainer();
      final package = OfflineMaterialPackage(
        parts: const [],
        totalSize: 0,
        totalParts: 0,
      );

      await container
          .read(offlineReconcileProvider.notifier)
          .requestReconcile(
            materialPackage: package,
            materialCategory: 'Partitura',
          );

      expect(reconcile.callCount, 1);
      expect(reconcile.lastPackage, same(package));
    },
  );

  test('StorageUnavailableException na migração não escapa', () async {
    migrate.throwStorageUnavailable = true;
    final container = createContainer();

    await container.read(offlineReconcileProvider.notifier).requestReconcile();

    expect(reconcile.callCount, 0);
    expect(
      container.read(offlineReconcileProvider).lastSkipReason,
      ReconcileSkipReason.indexUnavailable,
    );
    expect(container.read(offlineMaintenanceLockProvider), isNull);
  });
}
