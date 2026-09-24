import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/entities/reconcile_result.dart';
import 'package:coldigui/features/offline/domain/ports/pdf_storage_port.dart';
import 'package:coldigui/features/offline/domain/usecases/reconcile_offline_index.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_reconcile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Store que só sabe o tamanho do acervo — o resto não é chamado aqui.
class _BytesPort implements PdfStoragePort {
  _BytesPort(this.bytes);

  final int bytes;

  @override
  Future<int> getTotalOfflineBytes() async => bytes;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

List<Override> _offlineCacheStatusTestOverrides({int diskBytes = 0}) => [
  pdfStoragePortProvider.overrideWithValue(_BytesPort(diskBytes)),
];

void main() {
  test('refresh lê o uso de disco', () async {
    final container = ProviderContainer(
      overrides: _offlineCacheStatusTestOverrides(diskBytes: 2048),
    );
    addTearDown(container.dispose);

    await container.read(offlineCacheStatusProvider.notifier).refresh();

    final status = container.read(offlineCacheStatusProvider);
    expect(status.diskUsageBytes, 2048);
    expect(status.removedCount, 0);
  });

  test('refresh with removedCount propagates aviso', () async {
    final container = ProviderContainer(
      overrides: _offlineCacheStatusTestOverrides(),
    );
    addTearDown(container.dispose);

    await container
        .read(offlineCacheStatusProvider.notifier)
        .refresh(removedCount: 3);

    expect(
      container.read(offlineCacheStatusProvider).showRemovedWarning,
      isTrue,
    );
    expect(container.read(offlineCacheStatusProvider).removedCount, 3);
  });

  test('dismissRemovedWarning clears removedCount', () async {
    final container = ProviderContainer(
      overrides: _offlineCacheStatusTestOverrides(),
    );
    addTearDown(container.dispose);

    await container
        .read(offlineCacheStatusProvider.notifier)
        .refresh(removedCount: 2);
    container.read(offlineCacheStatusProvider.notifier).dismissRemovedWarning();

    expect(container.read(offlineCacheStatusProvider).removedCount, 0);
    expect(
      container.read(offlineCacheStatusProvider).showRemovedWarning,
      isFalse,
    );
  });

  test('reconcile completion triggers refresh with removedFromIndex', () async {
    final container = ProviderContainer(
      overrides: [
        ..._offlineCacheStatusTestOverrides(diskBytes: 1024),
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
    expect(status.diskUsageBytes, 1024);
    expect(status.removedCount, 2);
  });

  test(
    'refreshAll com reconcile pulado não propaga removedCount velho',
    () async {
      final container = ProviderContainer(
        overrides: [
          ..._offlineCacheStatusTestOverrides(diskBytes: 1024),
          offlineReconcileProvider.overrideWith(_SkippedReconcileNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      container.read(offlineCacheStatusProvider);
      await Future<void>.delayed(Duration.zero);

      await container.read(offlineCacheStatusProvider.notifier).refreshAll();

      final status = container.read(offlineCacheStatusProvider);
      expect(status.diskUsageBytes, 1024);
      expect(status.removedCount, 0);
      expect(status.showRemovedWarning, isFalse);
    },
  );
}

/// Reconcile que devolve um `lastResult` antigo e sinaliza que foi pulado —
/// o `removedFromIndex` dele não vale para esta rodada.
class _SkippedReconcileNotifier extends OfflineReconcileNotifier {
  @override
  OfflineReconcileState build() => const OfflineReconcileState(
    lastResult: ReconcileResult(removedFromIndex: 5, orphanFiles: 0),
  );

  @override
  Future<void> requestReconcile() async {
    state = state.copyWith(lastSkipReason: ReconcileSkipReason.locked);
  }
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
