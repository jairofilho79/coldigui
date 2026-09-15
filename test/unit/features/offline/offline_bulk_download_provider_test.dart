import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/failures/app_failure.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';

import 'offline_test_helpers.dart';

import 'package:coldigui/features/offline/data/datasources/offline_bulk_checkpoint_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_manifest_remote_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/domain/ports/pdf_storage_port.dart';
import 'package:coldigui/features/offline/data/datasources/zip_package_downloader.dart';
import 'package:coldigui/features/offline/data/providers/offline_bulk_providers.dart';
import 'package:coldigui/features/offline/domain/entities/offline_bulk_checkpoint.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/entities/offline_download_progress.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:coldigui/features/offline/domain/usecases/download_offline_packages.dart';
import 'package:coldigui/features/offline/domain/usecases/extract_and_store_pdfs.dart';
import 'package:coldigui/features/offline/domain/usecases/reconcile_offline_index.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_bulk_download_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_maintenance_lock_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_mode_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<void> removeMany(Set<String> pdfIds) async {}

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

class _ThrowingDownloadOfflinePackages extends DownloadOfflinePackages {
  _ThrowingDownloadOfflinePackages({
    required this.error,
    required PdfStoragePort store,
    required SharedPreferences prefs,
    required super.checkpointStore,
  }) : super(
         manifestDatasource: OfflineManifestRemoteDatasource(Dio(), prefs),
         zipDownloader: ZipPackageDownloader(Dio(), store),
         extractAndStorePdfs: ExtractAndStorePdfs(
           _StubRepo(),
           store,
           ZipPackageDownloader(Dio(), store),
         ),
         reconcileOfflineIndex: ReconcileOfflineIndex(_StubRepo(), store),
       );

  final Object error;

  @override
  Future<DownloadOfflinePackagesResult> call({
    required List<String> categories,
    void Function(OfflineDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
    OfflineBulkCheckpoint? resumeCheckpoint,
  }) async {
    throw error;
  }
}

/// Wakelock que falha ao ligar — cobre o vazamento do lock de manutenção.
class _ThrowingWakelock implements BulkDownloadWakelock {
  @override
  Future<void> enable() async => throw StateError('wakelock indisponível');

  @override
  Future<void> disable() async {}
}

class _FakeWakelock implements BulkDownloadWakelock {
  var enableCount = 0;
  var disableCount = 0;

  @override
  Future<void> enable() async => enableCount++;

  @override
  Future<void> disable() async => disableCount++;
}

class _SuccessDownloadOfflinePackages extends DownloadOfflinePackages {
  _SuccessDownloadOfflinePackages({
    required PdfStoragePort store,
    required SharedPreferences prefs,
    required super.checkpointStore,
  }) : super(
         manifestDatasource: OfflineManifestRemoteDatasource(Dio(), prefs),
         zipDownloader: ZipPackageDownloader(Dio(), store),
         extractAndStorePdfs: ExtractAndStorePdfs(
           _StubRepo(),
           store,
           ZipPackageDownloader(Dio(), store),
         ),
         reconcileOfflineIndex: ReconcileOfflineIndex(_StubRepo(), store),
       );

  @override
  Future<DownloadOfflinePackagesResult> call({
    required List<String> categories,
    void Function(OfflineDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
    OfflineBulkCheckpoint? resumeCheckpoint,
  }) async => const DownloadOfflinePackagesResult();
}

class _IdleOfflineModeNotifier extends OfflineModeNotifier {
  @override
  bool build() => false;

  @override
  Future<void> markConfigured() async {}
}

/// Registra chamadas a [markConfigured] sem persistir nada (Task 3/B4).
class _TrackingOfflineModeNotifier extends OfflineModeNotifier {
  var markConfiguredCallCount = 0;

  @override
  bool build() => false;

  @override
  Future<void> markConfigured() async {
    markConfiguredCallCount++;
  }
}

/// Usecase fake que retorna um [DownloadOfflinePackagesResult] fixo — usado
/// para exercitar `_completeBulkDownload` com falhas parciais/totais.
class _ResultDownloadOfflinePackages extends DownloadOfflinePackages {
  _ResultDownloadOfflinePackages({
    required this.result,
    required PdfStoragePort store,
    required SharedPreferences prefs,
    required super.checkpointStore,
  }) : super(
         manifestDatasource: OfflineManifestRemoteDatasource(Dio(), prefs),
         zipDownloader: ZipPackageDownloader(Dio(), store),
         extractAndStorePdfs: ExtractAndStorePdfs(
           _StubRepo(),
           store,
           ZipPackageDownloader(Dio(), store),
         ),
         reconcileOfflineIndex: ReconcileOfflineIndex(_StubRepo(), store),
       );

  final DownloadOfflinePackagesResult result;

  @override
  Future<DownloadOfflinePackagesResult> call({
    required List<String> categories,
    void Function(OfflineDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
    OfflineBulkCheckpoint? resumeCheckpoint,
  }) async => result;
}

/// Usecase fake que só conta execuções — usado nos testes de lock (spec C.1).
class _CountingDownloadOfflinePackages extends DownloadOfflinePackages {
  _CountingDownloadOfflinePackages({
    required PdfStoragePort store,
    required SharedPreferences prefs,
    required super.checkpointStore,
  }) : super(
         manifestDatasource: OfflineManifestRemoteDatasource(Dio(), prefs),
         zipDownloader: ZipPackageDownloader(Dio(), store),
         extractAndStorePdfs: ExtractAndStorePdfs(
           _StubRepo(),
           store,
           ZipPackageDownloader(Dio(), store),
         ),
         reconcileOfflineIndex: ReconcileOfflineIndex(_StubRepo(), store),
       );

  int callCount = 0;

  @override
  Future<DownloadOfflinePackagesResult> call({
    required List<String> categories,
    void Function(OfflineDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
    OfflineBulkCheckpoint? resumeCheckpoint,
  }) async {
    callCount++;
    return const DownloadOfflinePackagesResult();
  }
}

class _IdleCacheStatusNotifier extends OfflineCacheStatusNotifier {
  @override
  OfflineCacheStatus build() => OfflineCacheStatus.empty;

  @override
  Future<void> refresh({int? removedCount}) async {}

  @override
  Future<void> refreshAll() async {}
}

void main() {
  late SharedPreferences prefs;
  late PdfLocalStore store;
  late OfflineBulkCheckpointStore checkpointStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async =>
          Directory.systemTemp.createTempSync('bulk_provider_test_'),
    );
    checkpointStore = OfflineBulkCheckpointStore(prefs);
  });

  ProviderContainer createContainer(
    Object error, {
    BulkDownloadWakelock? wakelock,
    DownloadOfflinePackages? useCase,
  }) {
    final fakeWakelock = wakelock ?? _FakeWakelock();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bulkDownloadWakelockProvider.overrideWithValue(fakeWakelock),
        downloadOfflinePackagesProvider.overrideWith(
          (ref) =>
              useCase ??
              _ThrowingDownloadOfflinePackages(
                error: error,
                store: pdfStoragePortFor(store),
                prefs: prefs,
                checkpointStore: checkpointStore,
              ),
        ),
        offlineModeProvider.overrideWith(_IdleOfflineModeNotifier.new),
        offlineCacheStatusProvider.overrideWith(_IdleCacheStatusNotifier.new),
        isarAvailableProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpMicrotasks() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('DioException receiveTimeout vira NetworkFailure (E8)', () {
    final failure = AppFailure.from(
      DioException(
        requestOptions: RequestOptions(path: '/packages/test.zip'),
        type: DioExceptionType.receiveTimeout,
      ),
    );
    expect(failure, isA<NetworkFailure>());
  });

  test('DioException connectionError vira NetworkFailure (E8)', () {
    final failure = AppFailure.from(
      DioException(
        requestOptions: RequestOptions(path: '/packages/test.zip'),
        type: DioExceptionType.connectionError,
      ),
    );
    expect(failure, isA<NetworkFailure>());
  });

  test(
    'start com DioException receiveTimeout define failure NetworkFailure (E8)',
    () async {
      final container = createContainer(
        DioException(
          requestOptions: RequestOptions(path: '/packages/test.zip'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await pumpMicrotasks();

      await container.read(offlineBulkDownloadProvider.notifier).start([
        'Partitura',
      ]);

      final state = container.read(offlineBulkDownloadProvider);
      expect(state.status, OfflineBulkDownloadStatus.failed);
      expect(state.failure, isA<NetworkFailure>());
    },
  );

  test(
    'start com DioException connectionError define failure NetworkFailure (E8)',
    () async {
      final container = createContainer(
        DioException(
          requestOptions: RequestOptions(path: '/packages/test.zip'),
          type: DioExceptionType.connectionError,
        ),
      );
      await pumpMicrotasks();

      await container.read(offlineBulkDownloadProvider.notifier).start([
        'Partitura',
      ]);

      final state = container.read(offlineBulkDownloadProvider);
      expect(state.status, OfflineBulkDownloadStatus.failed);
      expect(state.failure, isA<NetworkFailure>());
    },
  );

  test('wakelock habilitado ao iniciar bulk e liberado ao falhar', () async {
    final wakelock = _FakeWakelock();
    final container = createContainer(
      DioException(
        requestOptions: RequestOptions(path: '/packages/test.zip'),
        type: DioExceptionType.receiveTimeout,
      ),
      wakelock: wakelock,
    );
    await pumpMicrotasks();

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
    ]);

    expect(wakelock.enableCount, 1);
    expect(wakelock.disableCount, 1);
  });

  test('wakelock liberado ao concluir bulk com sucesso', () async {
    final wakelock = _FakeWakelock();
    final container = createContainer(
      StateError('unused'),
      wakelock: wakelock,
      useCase: _SuccessDownloadOfflinePackages(
        store: pdfStoragePortFor(store),
        prefs: prefs,
        checkpointStore: checkpointStore,
      ),
    );
    await pumpMicrotasks();

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
    ]);

    expect(wakelock.enableCount, 1);
    expect(wakelock.disableCount, 1);
    expect(
      container.read(offlineBulkDownloadProvider).status,
      OfflineBulkDownloadStatus.completed,
    );
  });

  test('wakelock liberado ao cancelar bulk', () async {
    final wakelock = _FakeWakelock();
    final container = createContainer(
      const OfflineBulkCancelledException(),
      wakelock: wakelock,
    );
    await pumpMicrotasks();

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
    ]);

    expect(wakelock.enableCount, 1);
    expect(wakelock.disableCount, 1);
    expect(
      container.read(offlineBulkDownloadProvider).status,
      OfflineBulkDownloadStatus.cancelled,
    );
  });

  test('InsufficientDiskSpaceException define estado failed com StorageFailure (E8) '
      'e não chama markConfigured (Task 3/B4)', () async {
    final offlineMode = _TrackingOfflineModeNotifier();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bulkDownloadWakelockProvider.overrideWithValue(_FakeWakelock()),
        downloadOfflinePackagesProvider.overrideWith(
          (ref) => _ThrowingDownloadOfflinePackages(
            error: const InsufficientDiskSpaceException(
              requiredBytes: 5000,
              availableBytes: 0,
            ),
            store: pdfStoragePortFor(store),
            prefs: prefs,
            checkpointStore: checkpointStore,
          ),
        ),
        offlineModeProvider.overrideWith(() => offlineMode),
        offlineCacheStatusProvider.overrideWith(_IdleCacheStatusNotifier.new),
        isarAvailableProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    await pumpMicrotasks();

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
    ]);

    final state = container.read(offlineBulkDownloadProvider);
    expect(state.status, OfflineBulkDownloadStatus.failed);
    expect(state.failure, isA<StorageFailure>());
    expect(offlineMode.markConfiguredCallCount, 0);
  });

  test('2 falhas em 10 completa com completedWithWarnings, failedCount == 2 e '
      'chama markConfigured (Task 3/B4)', () async {
    final offlineMode = _TrackingOfflineModeNotifier();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bulkDownloadWakelockProvider.overrideWithValue(_FakeWakelock()),
        downloadOfflinePackagesProvider.overrideWith(
          (ref) => _ResultDownloadOfflinePackages(
            result: const DownloadOfflinePackagesResult(
              failedPdfIds: ['pdf-a', 'pdf-b'],
              totalPdfs: 10,
            ),
            store: pdfStoragePortFor(store),
            prefs: prefs,
            checkpointStore: checkpointStore,
          ),
        ),
        offlineModeProvider.overrideWith(() => offlineMode),
        offlineCacheStatusProvider.overrideWith(_IdleCacheStatusNotifier.new),
        isarAvailableProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    await pumpMicrotasks();

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
    ]);

    final state = container.read(offlineBulkDownloadProvider);
    expect(state.status, OfflineBulkDownloadStatus.completedWithWarnings);
    expect(state.failedCount, 2);
    expect(offlineMode.markConfiguredCallCount, 1);
  });

  test(
    'quando failedPdfIds cobre 100% do totalPdfs (nada foi gravado) não chama '
    'markConfigured mesmo sem exceção fatal (Task 3/B4)',
    () async {
      final offlineMode = _TrackingOfflineModeNotifier();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bulkDownloadWakelockProvider.overrideWithValue(_FakeWakelock()),
          downloadOfflinePackagesProvider.overrideWith(
            (ref) => _ResultDownloadOfflinePackages(
              result: const DownloadOfflinePackagesResult(
                failedPdfIds: ['pdf-a', 'pdf-b', 'pdf-c'],
                totalPdfs: 3,
              ),
              store: pdfStoragePortFor(store),
              prefs: prefs,
              checkpointStore: checkpointStore,
            ),
          ),
          offlineModeProvider.overrideWith(() => offlineMode),
          offlineCacheStatusProvider.overrideWith(_IdleCacheStatusNotifier.new),
          isarAvailableProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      await pumpMicrotasks();

      await container.read(offlineBulkDownloadProvider.notifier).start([
        'Partitura',
      ]);

      final state = container.read(offlineBulkDownloadProvider);
      expect(state.status, OfflineBulkDownloadStatus.completedWithWarnings);
      expect(state.failedCount, 3);
      expect(offlineMode.markConfiguredCallCount, 0);
    },
  );

  test('StorageUnavailableException vira StorageFailure (E8)', () {
    expect(
      AppFailure.from(
        const StorageUnavailableException('offline.putAllByPdfId'),
      ),
      isA<StorageFailure>(),
    );
  });

  test('bulk com Isar indisponível falha antes de baixar', () async {
    final useCase = _CountingDownloadOfflinePackages(
      store: pdfStoragePortFor(store),
      prefs: prefs,
      checkpointStore: checkpointStore,
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bulkDownloadWakelockProvider.overrideWithValue(_FakeWakelock()),
        downloadOfflinePackagesProvider.overrideWith((ref) => useCase),
        offlineModeProvider.overrideWith(_IdleOfflineModeNotifier.new),
        offlineCacheStatusProvider.overrideWith(_IdleCacheStatusNotifier.new),
        isarAvailableProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    await pumpMicrotasks();

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
    ]);

    final state = container.read(offlineBulkDownloadProvider);
    expect(state.status, OfflineBulkDownloadStatus.failed);
    expect(state.failure, isA<StorageFailure>());
    expect(useCase.callCount, 0);
  });

  test('bulk não roda com o lock de manutenção tomado', () async {
    final useCase = _CountingDownloadOfflinePackages(
      store: pdfStoragePortFor(store),
      prefs: prefs,
      checkpointStore: checkpointStore,
    );
    final container = createContainer(Object(), useCase: useCase);
    await pumpMicrotasks();
    container
        .read(offlineMaintenanceLockProvider.notifier)
        .tryAcquire(OfflineMaintenanceOwner.clear);

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
    ]);

    expect(useCase.callCount, 0);
    expect(
      container.read(offlineBulkDownloadProvider).status,
      OfflineBulkDownloadStatus.idle,
    );
  });

  test('bulk libera o lock de manutenção ao concluir', () async {
    final useCase = _CountingDownloadOfflinePackages(
      store: pdfStoragePortFor(store),
      prefs: prefs,
      checkpointStore: checkpointStore,
    );
    final container = createContainer(Object(), useCase: useCase);
    await pumpMicrotasks();

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
    ]);

    expect(useCase.callCount, 1);
    expect(container.read(offlineMaintenanceLockProvider), isNull);
  });

  test('start libera o lock de manutenção se o wakelock falhar', () async {
    final useCase = _CountingDownloadOfflinePackages(
      store: pdfStoragePortFor(store),
      prefs: prefs,
      checkpointStore: checkpointStore,
    );
    final container = createContainer(
      Object(),
      wakelock: _ThrowingWakelock(),
      useCase: useCase,
    );
    await pumpMicrotasks();

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
    ]);

    expect(useCase.callCount, 0);
    expect(
      container.read(offlineBulkDownloadProvider).status,
      OfflineBulkDownloadStatus.failed,
    );
    expect(container.read(offlineMaintenanceLockProvider), isNull);
  });

  test(
    'resumeFromCheckpoint libera o lock de manutenção se o wakelock falhar',
    () async {
      await checkpointStore.save(
        OfflineBulkCheckpoint(
          categories: const ['Partitura'],
          categoryIndex: 0,
          partIndex: 0,
          extractedPdfCount: 0,
          startedAt: DateTime.now(),
        ),
      );
      final useCase = _CountingDownloadOfflinePackages(
        store: pdfStoragePortFor(store),
        prefs: prefs,
        checkpointStore: checkpointStore,
      );
      final container = createContainer(
        Object(),
        wakelock: _ThrowingWakelock(),
        useCase: useCase,
      );
      await pumpMicrotasks();

      await container
          .read(offlineBulkDownloadProvider.notifier)
          .resumeFromCheckpoint();

      expect(useCase.callCount, 0);
      expect(container.read(offlineMaintenanceLockProvider), isNull);
    },
  );

  test('bulk libera o lock de manutenção ao falhar', () async {
    final container = createContainer(
      DioException(
        requestOptions: RequestOptions(path: '/packages/test.zip'),
        type: DioExceptionType.connectionError,
      ),
    );
    await pumpMicrotasks();

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
    ]);

    expect(
      container.read(offlineBulkDownloadProvider).status,
      OfflineBulkDownloadStatus.failed,
    );
    expect(container.read(offlineMaintenanceLockProvider), isNull);
  });
}
