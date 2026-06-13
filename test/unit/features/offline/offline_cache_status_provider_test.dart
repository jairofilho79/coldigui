import 'dart:typed_data';

import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/offline_manifest_remote_datasource.dart';
import 'package:coldigui/features/offline/domain/entities/offline_stats.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_reconcile_provider.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/entities/reconcile_result.dart';
import 'package:coldigui/features/offline/domain/usecases/get_offline_stats_by_category.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

class _StatsRepo implements OfflinePdfRepository {
  _StatsRepo(this.byCategory);

  final Map<String, int> byCategory;

  @override
  Future<Map<String, int>> countByCategory() async => byCategory;

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
  Future<int> removeIndexEntries(Set<String> pdfIds) async => 0;

  @override
  Future<OfflinePdfEntry> upsert({
    required String pdfId,
    required Uint8List bytes,
    required String category,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> upsertBatch(List<OfflinePdfBatchItem> items) async {}
}

class _StubCatalogLocal extends CatalogLocalDatasource {
  _StubCatalogLocal() : super(_StubIsar());

  @override
  Future<Map<String, String>> loadPdfIdToCategoriaMap() async => const {};
}

class _StubManifestDatasource extends OfflineManifestRemoteDatasource {
  _StubManifestDatasource() : super(Dio());
}

class _StubIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FixedGetOfflineStatsByCategory extends GetOfflineStatsByCategory {
  _FixedGetOfflineStatsByCategory(this.result)
      : super(_StatsRepo({}), _StubCatalogLocal(), _StubManifestDatasource());

  final OfflineStats result;

  @override
  Future<OfflineStats> call({bool includeMissing = true}) async => result;
}

void main() {
  test('refresh populates stats and isReady', () async {
    final container = ProviderContainer(
      overrides: [
        getOfflineStatsByCategoryProvider.overrideWith(
          (ref) => _FixedGetOfflineStatsByCategory(
            const OfflineStats(byCategory: {'Partitura': 2}),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(offlineCacheStatusProvider.notifier).refresh();

    final status = container.read(offlineCacheStatusProvider);
    expect(status.validCount, 2);
    expect(status.isReady, isTrue);
    expect(status.removedCount, 0);
  });

  test('refresh with removedCount propagates aviso', () async {
    final container = ProviderContainer(
      overrides: [
        getOfflineStatsByCategoryProvider.overrideWith(
          (ref) => _FixedGetOfflineStatsByCategory(
            const OfflineStats(byCategory: {}),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(offlineCacheStatusProvider.notifier).refresh(
          removedCount: 3,
        );

    expect(
        container.read(offlineCacheStatusProvider).showRemovedWarning, isTrue);
    expect(container.read(offlineCacheStatusProvider).removedCount, 3);
  });

  test('dismissRemovedWarning clears removedCount', () async {
    final container = ProviderContainer(
      overrides: [
        getOfflineStatsByCategoryProvider.overrideWith(
          (ref) => _FixedGetOfflineStatsByCategory(
            const OfflineStats(byCategory: {}),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(offlineCacheStatusProvider.notifier).refresh(
          removedCount: 2,
        );
    container.read(offlineCacheStatusProvider.notifier).dismissRemovedWarning();

    expect(container.read(offlineCacheStatusProvider).removedCount, 0);
    expect(
        container.read(offlineCacheStatusProvider).showRemovedWarning, isFalse);
  });

  test('reconcile completion triggers refresh with removedFromIndex', () async {
    final container = ProviderContainer(
      overrides: [
        getOfflineStatsByCategoryProvider.overrideWith(
          (ref) => _FixedGetOfflineStatsByCategory(
            const OfflineStats(byCategory: {'Partitura': 1}),
          ),
        ),
        offlineReconcileProvider.overrideWith(_TestReconcileNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(offlineCacheStatusProvider);
    await Future<void>.delayed(Duration.zero);

    await container.read(offlineReconcileProvider.notifier).requestReconcile();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final status = container.read(offlineCacheStatusProvider);
    expect(status.validCount, 1);
    expect(status.removedCount, 2);
  });
}

class _TestReconcileNotifier extends OfflineReconcileNotifier {
  @override
  Future<void> requestReconcile() async {
    state = state.copyWith(isRunning: true);
    await Future<void>.delayed(Duration.zero);
    state = OfflineReconcileState(
      lastResult: const ReconcileResult(removedFromIndex: 2, orphanFiles: 0),
      lastRunAt: DateTime.now(),
    );
  }
}
