import 'dart:async';
import 'dart:typed_data';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/failures/app_failure.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/favorite_pdf_ids_resolver.dart';
import 'package:coldigui/features/offline/data/providers/offline_core_providers.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/download_missing_pdfs.dart';
import 'package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_bulk_download_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_maintenance_lock_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_mode_provider.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
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

/// Base dos fakes: dependências inertes — nenhum teste aqui exercita o
/// download real, só a orquestração do notifier.
abstract class _FakeDownloadMissingPdfs extends DownloadMissingPdfs {
  _FakeDownloadMissingPdfs()
    : super(
        const CatalogLocalDatasource.unavailable(),
        _StubRepo(),
        FetchAndStorePdf(
          PdfBytesDatasource(Dio()),
          _StubRepo(),
          favoritePdfIdsResolver: FavoritePdfIdsResolver.testing(),
        ),
      );
}

class _ThrowingDownloadMissingPdfs extends _FakeDownloadMissingPdfs {
  _ThrowingDownloadMissingPdfs(this.error);
  final Object error;

  @override
  Future<DownloadMissingResult> call({
    Set<String>? materialCategories,
    void Function(int done, int total)? onProgress,
    CancelToken? cancelToken,
  }) async => throw error;
}

/// Usecase fake que retorna um [DownloadMissingResult] fixo e conta execuções
/// — cobre `_completeBulkDownload` (falhas parciais/totais) e os testes de
/// lock (spec C.1).
class _ResultDownloadMissingPdfs extends _FakeDownloadMissingPdfs {
  _ResultDownloadMissingPdfs(this.result);
  final DownloadMissingResult result;
  int callCount = 0;
  Set<String>? lastCategories;

  @override
  Future<DownloadMissingResult> call({
    Set<String>? materialCategories,
    void Function(int done, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    callCount++;
    lastCategories = materialCategories;
    return result;
  }
}

/// Emite progresso e só termina quando [gate] completa — para testar
/// «Parar» e a `ProgressSection`.
class _GatedDownloadMissingPdfs extends _FakeDownloadMissingPdfs {
  final gate = Completer<void>();
  CancelToken? token;

  @override
  Future<DownloadMissingResult> call({
    Set<String>? materialCategories,
    void Function(int done, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    token = cancelToken;
    onProgress?.call(0, 10);
    onProgress?.call(3, 10);
    await gate.future;
    if (cancelToken?.isCancelled ?? false) {
      throw const OfflineBulkCancelledException();
    }
    return const DownloadMissingResult(
      downloadedCount: 10,
      skippedCount: 0,
      failedCount: 0,
    );
  }
}

const _success = DownloadMissingResult(
  downloadedCount: 5,
  skippedCount: 0,
  failedCount: 0,
);

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer(
    Object error, {
    BulkDownloadWakelock? wakelock,
    DownloadMissingPdfs? useCase,
  }) {
    final fakeWakelock = wakelock ?? _FakeWakelock();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bulkDownloadWakelockProvider.overrideWithValue(fakeWakelock),
        downloadMissingPdfsProvider.overrideWithValue(
          useCase ?? _ThrowingDownloadMissingPdfs(error),
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
        requestOptions: RequestOptions(path: '/assets/test.pdf'),
        type: DioExceptionType.receiveTimeout,
      ),
    );
    expect(failure, isA<NetworkFailure>());
  });

  test('DioException connectionError vira NetworkFailure (E8)', () {
    final failure = AppFailure.from(
      DioException(
        requestOptions: RequestOptions(path: '/assets/test.pdf'),
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
          requestOptions: RequestOptions(path: '/assets/test.pdf'),
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
          requestOptions: RequestOptions(path: '/assets/test.pdf'),
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
        requestOptions: RequestOptions(path: '/assets/test.pdf'),
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
      useCase: _ResultDownloadMissingPdfs(_success),
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
        downloadMissingPdfsProvider.overrideWithValue(
          _ThrowingDownloadMissingPdfs(
            const InsufficientDiskSpaceException(
              requiredBytes: 5000,
              availableBytes: 0,
            ),
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
        downloadMissingPdfsProvider.overrideWithValue(
          _ResultDownloadMissingPdfs(
            const DownloadMissingResult(
              downloadedCount: 8,
              skippedCount: 0,
              failedCount: 2,
            ),
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

  test('quando todas as tentativas falham (nada foi gravado) não chama '
      'markConfigured mesmo sem exceção fatal (Task 3/B4)', () async {
    final offlineMode = _TrackingOfflineModeNotifier();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bulkDownloadWakelockProvider.overrideWithValue(_FakeWakelock()),
        downloadMissingPdfsProvider.overrideWithValue(
          _ResultDownloadMissingPdfs(
            const DownloadMissingResult(
              downloadedCount: 0,
              skippedCount: 0,
              failedCount: 10,
            ),
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
    expect(state.failedCount, 10);
    expect(offlineMode.markConfiguredCallCount, 0);
  });

  test('StorageUnavailableException vira StorageFailure (E8)', () {
    expect(
      AppFailure.from(
        const StorageUnavailableException('offline.putAllByPdfId'),
      ),
      isA<StorageFailure>(),
    );
  });

  test('bulk com Isar indisponível falha antes de baixar', () async {
    final useCase = _ResultDownloadMissingPdfs(_success);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bulkDownloadWakelockProvider.overrideWithValue(_FakeWakelock()),
        downloadMissingPdfsProvider.overrideWithValue(useCase),
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
    final useCase = _ResultDownloadMissingPdfs(_success);
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
    final useCase = _ResultDownloadMissingPdfs(_success);
    final container = createContainer(Object(), useCase: useCase);
    await pumpMicrotasks();

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
    ]);

    expect(useCase.callCount, 1);
    expect(container.read(offlineMaintenanceLockProvider), isNull);
  });

  test('start libera o lock de manutenção se o wakelock falhar', () async {
    final useCase = _ResultDownloadMissingPdfs(_success);
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

  test('bulk libera o lock de manutenção ao falhar', () async {
    final container = createContainer(
      DioException(
        requestOptions: RequestOptions(path: '/assets/test.pdf'),
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

  test('start repassa as categorias e o cancel token ao use case', () async {
    final useCase = _ResultDownloadMissingPdfs(_success);
    final container = createContainer(Object(), useCase: useCase);

    await container.read(offlineBulkDownloadProvider.notifier).start([
      'Partitura',
      'Cifra',
    ]);

    expect(useCase.lastCategories, {'Partitura', 'Cifra'});
    expect(
      container.read(offlineBulkDownloadProvider).status,
      OfflineBulkDownloadStatus.completed,
    );
  });

  test(
    'progresso (done, total) chega ao estado com as categorias como rótulo',
    () async {
      final useCase = _GatedDownloadMissingPdfs();
      final container = createContainer(Object(), useCase: useCase);
      final notifier = container.read(offlineBulkDownloadProvider.notifier);

      final running = notifier.start(['Partitura']);
      await pumpMicrotasks();

      final progress = container.read(offlineBulkDownloadProvider).progress;
      expect(progress, isNotNull);
      expect(progress!.donePdfs, 3);
      expect(progress.totalPdfs, 10);
      expect(progress.currentCategory, 'Partitura');

      useCase.gate.complete();
      await running;
    },
  );

  test(
    'cancel cancela o token e termina em cancelled sem checkpoint',
    () async {
      final useCase = _GatedDownloadMissingPdfs();
      final container = createContainer(Object(), useCase: useCase);
      final notifier = container.read(offlineBulkDownloadProvider.notifier);

      final running = notifier.start(['Partitura']);
      await pumpMicrotasks();
      notifier.cancel();
      expect(
        container.read(offlineBulkDownloadProvider).status,
        OfflineBulkDownloadStatus.cancelling,
      );
      expect(useCase.token!.isCancelled, isTrue);

      useCase.gate.complete();
      await running;

      final state = container.read(offlineBulkDownloadProvider);
      expect(state.status, OfflineBulkDownloadStatus.cancelled);
      expect(state.progress, isNull);
    },
  );
}
