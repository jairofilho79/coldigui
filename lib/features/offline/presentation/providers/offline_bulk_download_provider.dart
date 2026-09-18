import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/failures/app_failure.dart';
import '../../data/providers/offline_core_providers.dart';
import 'offline_cache_status_provider.dart';
import 'offline_category_selection_provider.dart';
import 'offline_maintenance_lock_provider.dart';
import 'offline_mode_provider.dart';
import '../../domain/entities/offline_download_progress.dart';
import '../../domain/exceptions/offline_bulk_exceptions.dart';
import '../../domain/usecases/download_missing_pdfs.dart';

/// Mantém a tela ligada durante bulk download prolongado (backlog #12).
abstract interface class BulkDownloadWakelock {
  Future<void> enable();
  Future<void> disable();
}

class WakelockPlusBulkDownloadWakelock implements BulkDownloadWakelock {
  const WakelockPlusBulkDownloadWakelock();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

final bulkDownloadWakelockProvider = Provider<BulkDownloadWakelock>(
  (ref) => const WakelockPlusBulkDownloadWakelock(),
);

/// Estado do bulk download UC-09 na UI.
enum OfflineBulkDownloadStatus {
  idle,
  running,
  cancelling,
  completed,
  completedWithWarnings,
  failed,
  cancelled,
}

class OfflineBulkDownloadState {
  const OfflineBulkDownloadState({
    this.status = OfflineBulkDownloadStatus.idle,
    this.progress,
    this.failure,
    this.failedCount = 0,
  });

  final OfflineBulkDownloadStatus status;
  final OfflineDownloadProgress? progress;

  /// Falha classificada (E8) da última execução — a UI traduz via
  /// `failureMessage`.
  final AppFailure? failure;

  /// PDFs que falharam na última execução — diferencia `completed` de
  /// `completedWithWarnings` e alimenta "N falhas".
  final int failedCount;

  bool get isRunning => status == OfflineBulkDownloadStatus.running;
  bool get isCancelling => status == OfflineBulkDownloadStatus.cancelling;
  bool get isActive => isRunning || isCancelling;
  bool get completedWithWarnings =>
      status == OfflineBulkDownloadStatus.completedWithWarnings;

  OfflineBulkDownloadState copyWith({
    OfflineBulkDownloadStatus? status,
    OfflineDownloadProgress? progress,
    AppFailure? failure,
    int? failedCount,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return OfflineBulkDownloadState(
      status: status ?? this.status,
      progress: clearProgress ? null : (progress ?? this.progress),
      failure: clearError ? null : (failure ?? this.failure),
      failedCount: failedCount ?? this.failedCount,
    );
  }
}

final offlineBulkDownloadProvider =
    NotifierProvider<OfflineBulkDownloadNotifier, OfflineBulkDownloadState>(
      OfflineBulkDownloadNotifier.new,
    );

/// Orquestra [DownloadMissingPdfs] (PDF a PDF, do coldigom) com progresso,
/// cancelamento, [offlineModeProvider.markConfigured]
/// (`OFFLINE_AVAILABLE=TRUE`) e refresh de [offlineCacheStatusProvider].
///
/// Sem checkpoint: «retomar» é carregar em «Baixar selecionados» de novo — o
/// use case pré-filtra o que já está no índice (spec §6.2).
class OfflineBulkDownloadNotifier extends Notifier<OfflineBulkDownloadState> {
  CancelToken? _cancelToken;
  var _wakelockHeld = false;
  List<String> _lastStartedCategories = const [];

  BulkDownloadWakelock get _wakelock => ref.read(bulkDownloadWakelockProvider);

  @override
  OfflineBulkDownloadState build() {
    ref.onDispose(() {
      _cancelToken?.cancel();
      _releaseWakelock();
    });
    return const OfflineBulkDownloadState();
  }

  Future<void> _acquireWakelock() async {
    if (_wakelockHeld) return;
    await _wakelock.enable();
    _wakelockHeld = true;
  }

  Future<void> _releaseWakelock() async {
    if (!_wakelockHeld) return;
    await _wakelock.disable();
    _wakelockHeld = false;
  }

  Future<void> start(List<String> categories) async {
    if (state.isRunning) return;
    if (!_ensureStorageAvailable()) return;
    if (!_acquireMaintenanceLock()) return;

    // Tudo o que pode lançar fica dentro do try: o `finally` é a única
    // garantia de que o lock de manutenção não vaza pela sessão inteira.
    try {
      _lastStartedCategories = List<String>.from(categories);
      final label = categories.join(', ');
      final cancelToken = _cancelToken = CancelToken();
      state = state.copyWith(
        status: OfflineBulkDownloadStatus.running,
        clearError: true,
        clearProgress: true,
        failedCount: 0,
      );
      await _acquireWakelock();

      final result = await ref
          .read(downloadMissingPdfsProvider)
          .call(
            materialCategories: categories.toSet(),
            cancelToken: cancelToken,
            onProgress: (done, total) => _onDownloadProgress(
              OfflineDownloadProgress(
                currentCategory: label,
                donePdfs: done,
                totalPdfs: total,
              ),
            ),
          );

      await _completeBulkDownload(result);
    } on OfflineBulkCancelledException {
      await _releaseWakelock();
      state = state.copyWith(
        status: OfflineBulkDownloadStatus.cancelled,
        clearProgress: true,
      );
      await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
    } on Object catch (e) {
      await _failBulkDownload(e);
    } finally {
      _releaseMaintenanceLock();
    }
  }

  /// `false` (com estado `failed`) quando o Isar não abriu — spec C.1: não
  /// baixar um byte sem ter onde indexar.
  bool _ensureStorageAvailable() {
    if (ref.read(isarAvailableProvider)) return true;
    debugPrint('[offline] bulk abortado: índice offline indisponível');
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.failed,
      failure: const StorageFailure(
        StorageUnavailableException('offline.bulk'),
      ),
      clearProgress: true,
    );
    return false;
  }

  bool _acquireMaintenanceLock() {
    final acquired = ref
        .read(offlineMaintenanceLockProvider.notifier)
        .tryAcquire(OfflineMaintenanceOwner.bulk);
    if (!acquired) {
      debugPrint('[offline] bulk adiado: manutenção offline em andamento');
    }
    return acquired;
  }

  void _releaseMaintenanceLock() {
    ref
        .read(offlineMaintenanceLockProvider.notifier)
        .release(OfflineMaintenanceOwner.bulk);
  }

  void _onDownloadProgress(OfflineDownloadProgress progress) {
    if (state.status == OfflineBulkDownloadStatus.cancelling) {
      state = state.copyWith(progress: progress);
      return;
    }
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.running,
      progress: progress,
    );
  }

  Future<void> _failBulkDownload(Object error) async {
    await _releaseWakelock();
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.failed,
      failure: AppFailure.from(error),
      clearProgress: true,
    );
    await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
  }

  Future<void> _completeBulkDownload(DownloadMissingResult result) async {
    await _releaseWakelock();
    final failedCount = result.failedCount;
    final attempted = result.downloadedCount + failedCount;
    // Nada foi de fato gravado neste lote — não é honesto marcar
    // OFFLINE_AVAILABLE=TRUE (Task 3/B4).
    final nothingWasStored = attempted > 0 && result.downloadedCount == 0;
    state = state.copyWith(
      status: failedCount > 0
          ? OfflineBulkDownloadStatus.completedWithWarnings
          : OfflineBulkDownloadStatus.completed,
      clearProgress: true,
      failedCount: failedCount,
    );
    if (_lastStartedCategories.isNotEmpty) {
      await ref
          .read(offlineCategorySelectionProvider.notifier)
          .registerBulkCompleted(_lastStartedCategories);
    }
    _lastStartedCategories = const [];
    if (!nothingWasStored) {
      await ref.read(offlineModeProvider.notifier).markConfigured();
    }
    await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
  }

  void cancel() {
    if (!state.isRunning) return;
    _cancelToken?.cancel('cancelled by user');
    state = state.copyWith(status: OfflineBulkDownloadStatus.cancelling);
  }

  /// Para o bulk ao ir para background — o que já foi gravado fica.
  void pauseForBackground() {
    if (!state.isRunning) return;
    _cancelToken?.cancel('app backgrounded');
    state = state.copyWith(status: OfflineBulkDownloadStatus.cancelling);
  }
}
