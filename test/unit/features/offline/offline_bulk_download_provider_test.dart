import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/offline/data/datasources/offline_bulk_checkpoint_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_manifest_remote_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/datasources/zip_package_downloader.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
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
    required PdfLocalStore store,
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
    required PdfLocalStore store,
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

class _IdleCacheStatusNotifier extends OfflineCacheStatusNotifier {
  @override
  OfflineCacheStatus build() => OfflineCacheStatus.empty;

  @override
  Future<void> refresh({int? removedCount}) async {}
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
                store: store,
                prefs: prefs,
                checkpointStore: checkpointStore,
              ),
        ),
        offlineModeProvider.overrideWith(_IdleOfflineModeNotifier.new),
        offlineCacheStatusProvider.overrideWith(_IdleCacheStatusNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpMicrotasks() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('offlineBulkDownloadErrorKey mapeia receiveTimeout', () {
    final key = offlineBulkDownloadErrorKey(
      DioException(
        requestOptions: RequestOptions(path: '/packages/test.zip'),
        type: DioExceptionType.receiveTimeout,
      ),
    );
    expect(key, 'offlineDownloadTimeout');
  });

  test('offlineBulkDownloadErrorKey mapeia connectionError', () {
    final key = offlineBulkDownloadErrorKey(
      DioException(
        requestOptions: RequestOptions(path: '/packages/test.zip'),
        type: DioExceptionType.connectionError,
      ),
    );
    expect(key, 'offlineDownloadNetworkError');
  });

  test(
    'start com DioException receiveTimeout define offlineDownloadTimeout',
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
      expect(state.errorMessage, 'offlineDownloadTimeout');
    },
  );

  test(
    'start com DioException connectionError define offlineDownloadNetworkError',
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
      expect(state.errorMessage, 'offlineDownloadNetworkError');
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
        store: store,
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
}
