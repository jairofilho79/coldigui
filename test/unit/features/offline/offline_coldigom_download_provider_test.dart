import 'dart:async';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/features/offline/data/providers/offline_coldigom_providers.dart';
import 'package:coldigui/features/offline/domain/entities/coldigom_download_progress.dart';
import 'package:coldigui/features/offline/domain/usecases/download_coldigom_materials.dart';
import 'package:coldigui/features/offline/domain/usecases/remove_coldigom_downloads.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_bulk_download_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_download_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_stats_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_maintenance_lock_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Wakelock implements BulkDownloadWakelock {
  var enabled = 0;
  var disabled = 0;
  @override
  Future<void> enable() async => enabled++;
  @override
  Future<void> disable() async => disabled++;
}

/// Use case de roteiro: emite progresso, espera o `gate` e devolve o resultado.
class _ScriptedDownload implements DownloadColdigomMaterials {
  // `result` fica pronto para roteirizar um `done` com resultado
  // específico; nenhum teste atual precisa disso.
  // ignore: unused_element_parameter
  _ScriptedDownload({this.gate, this.result, this.error});
  final Completer<void>? gate;
  final ColdigomDownloadResult? result;
  final Object? error;
  Set<String>? kindIds;
  CancelToken? token;

  @override
  Future<ColdigomDownloadResult> call({
    required Set<String> kindIds,
    CancelToken? cancelToken,
    void Function(ColdigomDownloadProgress)? onProgress,
  }) async {
    this.kindIds = kindIds;
    token = cancelToken;
    onProgress?.call(
      const ColdigomDownloadProgress(
        kindId: 'k',
        doneInKind: 1,
        totalInKind: 2,
        doneTotal: 1,
        total: 2,
        currentTitle: '001 · x',
      ),
    );
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return result ??
        ColdigomDownloadResult(
          done: 1,
          skipped: 0,
          failed: const [],
          bytes: 10,
          cancelled: cancelToken?.isCancelled ?? false,
        );
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _Remove implements RemoveColdigomDownloads {
  var calls = 0;
  @override
  Future<RemoveColdigomDownloadsResult> call() async {
    calls++;
    return const RemoveColdigomDownloadsResult(
      removedPdfs: 2,
      removedAudios: 3,
    );
  }
}

void main() {
  late _Wakelock wakelock;

  ProviderContainer container(
    _ScriptedDownload download, {
    bool isar = true,
    _Remove? remove,
  }) {
    wakelock = _Wakelock();
    final c = ProviderContainer(
      overrides: [
        isarAvailableProvider.overrideWithValue(isar),
        downloadColdigomMaterialsProvider.overrideWithValue(download),
        removeColdigomDownloadsProvider.overrideWithValue(remove ?? _Remove()),
        bulkDownloadWakelockProvider.overrideWithValue(wakelock),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('start: lock + wakelock, progresso, done com resultado, revisão de cifra/gestos sobe', () async {
    final gate = Completer<void>();
    final download = _ScriptedDownload(gate: gate);
    final c = container(download);
    final notifier = c.read(offlineColdigomDownloadProvider.notifier);

    final future = notifier.start({'k'});
    await Future<void>.delayed(Duration.zero);
    expect(
      c.read(offlineColdigomDownloadProvider).status,
      OfflineColdigomDownloadStatus.running,
    );
    expect(c.read(offlineColdigomDownloadProvider).progress!.doneTotal, 1);
    expect(
      c.read(offlineMaintenanceLockProvider),
      OfflineMaintenanceOwner.coldigom,
    );
    expect(wakelock.enabled, 1);

    gate.complete();
    await future;
    final state = c.read(offlineColdigomDownloadProvider);
    expect(state.status, OfflineColdigomDownloadStatus.done);
    expect(state.result!.done, 1);
    expect(download.kindIds, {'k'});
    expect(c.read(offlineMaintenanceLockProvider), isNull);
    expect(wakelock.disabled, 1);
    expect(c.read(chordGestureCacheRevisionProvider), 1);
  });

  test(
    'stop cancela o token e o estado fica done com parcial cancelado',
    () async {
      final gate = Completer<void>();
      final download = _ScriptedDownload(gate: gate);
      final c = container(download);
      final notifier = c.read(offlineColdigomDownloadProvider.notifier);

      final future = notifier.start({'k'});
      await Future<void>.delayed(Duration.zero);
      notifier.stop();
      expect(
        c.read(offlineColdigomDownloadProvider).status,
        OfflineColdigomDownloadStatus.cancelling,
      );
      expect(download.token!.isCancelled, isTrue);
      gate.complete();
      await future;

      expect(
        c.read(offlineColdigomDownloadProvider).status,
        OfflineColdigomDownloadStatus.done,
      );
      expect(c.read(offlineColdigomDownloadProvider).result!.cancelled, isTrue);
    },
  );

  test(
    'sem Isar → failed sem tocar no use case; lock ocupado → não inicia',
    () async {
      final download = _ScriptedDownload();
      final c = container(download, isar: false);
      await c.read(offlineColdigomDownloadProvider.notifier).start({'k'});
      expect(
        c.read(offlineColdigomDownloadProvider).status,
        OfflineColdigomDownloadStatus.failed,
      );
      expect(download.kindIds, isNull);

      final c2 = container(_ScriptedDownload());
      c2
          .read(offlineMaintenanceLockProvider.notifier)
          .tryAcquire(OfflineMaintenanceOwner.bulk);
      await c2.read(offlineColdigomDownloadProvider.notifier).start({'k'});
      expect(
        c2.read(offlineColdigomDownloadProvider).status,
        OfflineColdigomDownloadStatus.idle,
      );
    },
  );

  test(
    'erro inesperado → failed com AppFailure e lock/wakelock libertados',
    () async {
      final c = container(_ScriptedDownload(error: StateError('boom')));
      await c.read(offlineColdigomDownloadProvider.notifier).start({'k'});

      expect(
        c.read(offlineColdigomDownloadProvider).status,
        OfflineColdigomDownloadStatus.failed,
      );
      expect(c.read(offlineColdigomDownloadProvider).failure, isNotNull);
      expect(c.read(offlineMaintenanceLockProvider), isNull);
      expect(wakelock.disabled, 1);
    },
  );

  test('removeDownloads usa o lock e devolve o resultado', () async {
    final remove = _Remove();
    final c = container(_ScriptedDownload(), remove: remove);

    final result = await c
        .read(offlineColdigomDownloadProvider.notifier)
        .removeDownloads();

    expect(result!.removedAudios, 3);
    expect(remove.calls, 1);
    expect(c.read(offlineMaintenanceLockProvider), isNull);
  });
}
