import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/failures/app_failure.dart';
import '../../data/providers/offline_coldigom_providers.dart';
import '../../domain/entities/coldigom_download_progress.dart';
import '../../domain/usecases/remove_coldigom_downloads.dart';
import 'offline_bulk_download_provider.dart' show bulkDownloadWakelockProvider;
import 'offline_coldigom_stats_provider.dart';
import 'offline_maintenance_lock_provider.dart';

enum OfflineColdigomDownloadStatus { idle, running, cancelling, done, failed }

/// Estado do download Coldigom por kind na tela `/offline` (§5.4).
class OfflineColdigomDownloadState {
  const OfflineColdigomDownloadState({
    this.status = OfflineColdigomDownloadStatus.idle,
    this.progress,
    this.result,
    this.failure,
  });

  final OfflineColdigomDownloadStatus status;
  final ColdigomDownloadProgress? progress;

  /// Resultado da última execução (inclui o parcial de um cancelamento).
  final ColdigomDownloadResult? result;
  final AppFailure? failure;

  bool get isRunning => status == OfflineColdigomDownloadStatus.running;
  bool get isActive =>
      isRunning || status == OfflineColdigomDownloadStatus.cancelling;

  OfflineColdigomDownloadState copyWith({
    OfflineColdigomDownloadStatus? status,
    ColdigomDownloadProgress? progress,
    ColdigomDownloadResult? result,
    AppFailure? failure,
    bool clearProgress = false,
  }) {
    return OfflineColdigomDownloadState(
      status: status ?? this.status,
      progress: clearProgress ? null : (progress ?? this.progress),
      result: result ?? this.result,
      failure: failure ?? this.failure,
    );
  }
}

final offlineColdigomDownloadProvider =
    NotifierProvider<
      OfflineColdigomDownloadNotifier,
      OfflineColdigomDownloadState
    >(OfflineColdigomDownloadNotifier.new);

/// Orquestra [DownloadColdigomMaterials] com lock de manutenção, wakelock e
/// cancelamento (§5.2). Bulk PLPCG e este são mutuamente exclusivos pelo
/// lock. Sem checkpoint (O12): parar guarda o parcial e «Tentar de novo»
/// simplesmente re-executa — o use case salta o que já está.
class OfflineColdigomDownloadNotifier
    extends Notifier<OfflineColdigomDownloadState> {
  CancelToken? _cancelToken;
  var _wakelockHeld = false;

  @override
  OfflineColdigomDownloadState build() {
    ref.onDispose(() {
      _cancelToken?.cancel();
      unawaited(_releaseWakelock());
    });
    return const OfflineColdigomDownloadState();
  }

  Future<void> start(Set<String> kindIds) async {
    if (state.isActive || kindIds.isEmpty) return;
    if (!ref.read(isarAvailableProvider)) {
      state = state.copyWith(
        status: OfflineColdigomDownloadStatus.failed,
        failure: const StorageFailure(
          StorageUnavailableException('offline.coldigom'),
        ),
      );
      return;
    }
    final lock = ref.read(offlineMaintenanceLockProvider.notifier);
    if (!lock.tryAcquire(OfflineMaintenanceOwner.coldigom)) return;

    try {
      _cancelToken = CancelToken();
      state = const OfflineColdigomDownloadState(
        status: OfflineColdigomDownloadStatus.running,
      );
      await _acquireWakelock();

      final result = await ref
          .read(downloadColdigomMaterialsProvider)
          .call(
            kindIds: kindIds,
            cancelToken: _cancelToken,
            onProgress: (progress) {
              if (!state.isActive) return;
              state = state.copyWith(progress: progress);
            },
          );
      state = OfflineColdigomDownloadState(
        status: OfflineColdigomDownloadStatus.done,
        result: result,
      );
    } on Object catch (error) {
      debugPrint('[offline] download coldigom falhou: $error');
      state = OfflineColdigomDownloadState(
        status: OfflineColdigomDownloadStatus.failed,
        failure: AppFailure.from(error),
      );
    } finally {
      await _releaseWakelock();
      lock.release(OfflineMaintenanceOwner.coldigom);
      // Cifras/gestos gravados em lote não avisam ninguém: sobe a revisão
      // para o mapa de disponibilidade e as stats re-derivarem.
      ref.read(chordGestureCacheRevisionProvider.notifier).bump();
    }
  }

  /// Pede paragem; o use case devolve o parcial e o estado vira `done`.
  void stop() {
    if (!state.isRunning) return;
    _cancelToken?.cancel();
    state = state.copyWith(status: OfflineColdigomDownloadStatus.cancelling);
  }

  /// iOS suspende o app em background: parar aqui evita um download «a
  /// meio» que só falharia (o parcial fica; retomar é re-executar, O12).
  void pauseForBackground() => stop();

  /// «Remover áudios e PDFs baixados do Coldigom»; `null` se o lock estiver
  /// ocupado ou não houver Isar.
  Future<RemoveColdigomDownloadsResult?> removeDownloads() async {
    if (state.isActive || !ref.read(isarAvailableProvider)) return null;
    final lock = ref.read(offlineMaintenanceLockProvider.notifier);
    if (!lock.tryAcquire(OfflineMaintenanceOwner.coldigom)) return null;
    try {
      return await ref.read(removeColdigomDownloadsProvider).call();
    } finally {
      lock.release(OfflineMaintenanceOwner.coldigom);
    }
  }

  Future<void> _acquireWakelock() async {
    if (_wakelockHeld) return;
    await ref.read(bulkDownloadWakelockProvider).enable();
    _wakelockHeld = true;
  }

  Future<void> _releaseWakelock() async {
    if (!_wakelockHeld) return;
    await ref.read(bulkDownloadWakelockProvider).disable();
    _wakelockHeld = false;
  }
}
