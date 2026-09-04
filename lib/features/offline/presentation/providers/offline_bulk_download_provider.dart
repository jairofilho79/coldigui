import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/database/storage_unavailable_exception.dart';
import '../../data/providers/offline_bulk_providers.dart';
import '../../data/providers/offline_core_providers.dart';
import 'offline_cache_status_provider.dart';
import 'offline_category_selection_provider.dart';
import 'offline_maintenance_lock_provider.dart';
import 'offline_mode_provider.dart';
import '../../domain/entities/offline_bulk_checkpoint.dart';
import '../../domain/entities/offline_download_progress.dart';
import '../../domain/exceptions/offline_bulk_exceptions.dart';
import '../../domain/usecases/download_offline_packages.dart';

/// Chave l10n usada quando o índice offline (Isar) não está disponível.
const offlineStorageUnavailableKey = 'offlineStorageUnavailable';

/// Chave l10n para falhas de bulk mapeadas a partir de exceções concretas.
String offlineBulkDownloadErrorKey(Object error) {
  if (error is StorageUnavailableException) {
    return offlineStorageUnavailableKey;
  }
  if (error is InsufficientDiskSpaceException) {
    return 'offlineDownloadNoSpace';
  }
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionTimeout => 'offlineDownloadTimeout',
      DioExceptionType.connectionError => 'offlineDownloadNetworkError',
      _ => 'offlineDownloadError',
    };
  }
  return 'offlineDownloadError';
}

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

/// Estado do bulk download UC-09 na UI (Fase 3.5).
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
    this.checkpoint,
    this.errorMessage,
    this.unmatchedZipEntries = const [],
    this.failedCount = 0,
  });

  final OfflineBulkDownloadStatus status;
  final OfflineDownloadProgress? progress;
  final OfflineBulkCheckpoint? checkpoint;
  final String? errorMessage;
  final List<String> unmatchedZipEntries;

  /// PDFs esperados que falharam na última execução (Task 3/B4) — usado para
  /// diferenciar `completed` de `completedWithWarnings` e exibir "N falhas".
  final int failedCount;

  bool get isRunning => status == OfflineBulkDownloadStatus.running;
  bool get isCancelling => status == OfflineBulkDownloadStatus.cancelling;
  bool get isActive => isRunning || isCancelling;
  bool get hasCheckpoint => checkpoint != null;
  bool get completedWithWarnings =>
      status == OfflineBulkDownloadStatus.completedWithWarnings;

  OfflineBulkDownloadState copyWith({
    OfflineBulkDownloadStatus? status,
    OfflineDownloadProgress? progress,
    OfflineBulkCheckpoint? checkpoint,
    String? errorMessage,
    List<String>? unmatchedZipEntries,
    int? failedCount,
    bool clearCheckpoint = false,
    bool clearError = false,
    bool clearUnmatchedZipEntries = false,
  }) {
    return OfflineBulkDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      checkpoint: clearCheckpoint ? null : (checkpoint ?? this.checkpoint),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      unmatchedZipEntries: clearUnmatchedZipEntries
          ? const []
          : (unmatchedZipEntries ?? this.unmatchedZipEntries),
      failedCount: failedCount ?? this.failedCount,
    );
  }
}

final offlineBulkDownloadProvider =
    NotifierProvider<OfflineBulkDownloadNotifier, OfflineBulkDownloadState>(
      OfflineBulkDownloadNotifier.new,
    );

/// Orquestra [DownloadOfflinePackages] com progresso, cancelamento,
/// [offlineModeProvider.markConfigured] (`OFFLINE_AVAILABLE=TRUE`) e refresh
/// de [offlineCacheStatusProvider] ao concluir (Fase 3.7).
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

    Future.microtask(_loadCheckpoint);

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

  Future<void> _loadCheckpoint() async {
    final checkpoint = await ref
        .read(offlineBulkCheckpointStoreProvider)
        .load();
    if (checkpoint != null) {
      state = state.copyWith(checkpoint: checkpoint);
    }
  }

  Future<void> start(List<String> categories) async {
    if (state.isRunning) return;
    if (!_ensureStorageAvailable()) return;
    if (!_acquireMaintenanceLock()) return;

    _lastStartedCategories = List<String>.from(categories);
    _cancelToken = CancelToken();
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.running,
      clearError: true,
      clearCheckpoint: true,
      clearUnmatchedZipEntries: true,
      failedCount: 0,
    );
    await _acquireWakelock();

    try {
      final result = await ref
          .read(downloadOfflinePackagesProvider)
          .call(
            categories: categories,
            cancelToken: _cancelToken,
            onProgress: (progress) => _onDownloadProgress(progress),
          );

      await _completeBulkDownload(result);
    } on OfflineBulkCancelledException {
      await _releaseWakelock();
      final checkpoint = await ref
          .read(offlineBulkCheckpointStoreProvider)
          .load();
      state = state.copyWith(
        status: OfflineBulkDownloadStatus.cancelled,
        checkpoint: checkpoint,
        progress: null,
      );
      await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
    } on InsufficientDiskSpaceException catch (e) {
      await _failBulkDownload(e);
    } on DioException catch (e) {
      await _failBulkDownload(e);
    } on Object catch (e) {
      await _failBulkDownload(e);
    } finally {
      _releaseMaintenanceLock();
    }
  }

  Future<void> resumeFromCheckpoint() async {
    if (state.isRunning) return;
    if (!_ensureStorageAvailable()) return;

    final checkpoint =
        state.checkpoint ??
        await ref.read(offlineBulkCheckpointStoreProvider).load();
    if (checkpoint == null) return;
    if (!_acquireMaintenanceLock()) return;

    _lastStartedCategories = List<String>.from(checkpoint.categories);
    _cancelToken = CancelToken();
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.running,
      clearError: true,
      failedCount: 0,
    );
    await _acquireWakelock();

    try {
      final result = await ref
          .read(downloadOfflinePackagesProvider)
          .call(
            categories: checkpoint.categories,
            cancelToken: _cancelToken,
            resumeCheckpoint: checkpoint,
            onProgress: (progress) => _onDownloadProgress(progress),
          );

      await _completeBulkDownload(result);
    } on OfflineBulkCancelledException {
      await _releaseWakelock();
      final saved = await ref.read(offlineBulkCheckpointStoreProvider).load();
      state = state.copyWith(
        status: OfflineBulkDownloadStatus.cancelled,
        checkpoint: saved,
        progress: null,
      );
      await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
    } on InsufficientDiskSpaceException catch (e) {
      await _failBulkDownload(e);
    } on DioException catch (e) {
      await _failBulkDownload(e);
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
      errorMessage: offlineStorageUnavailableKey,
      progress: null,
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
    final checkpoint = await ref
        .read(offlineBulkCheckpointStoreProvider)
        .load();
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.failed,
      errorMessage: offlineBulkDownloadErrorKey(error),
      checkpoint: checkpoint,
      progress: null,
    );
    await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
  }

  Future<void> _completeBulkDownload(
    DownloadOfflinePackagesResult result,
  ) async {
    await _releaseWakelock();
    final failedCount = result.failedPdfIds.length;
    // Nada foi de fato gravado neste lote — não é honesto marcar
    // OFFLINE_AVAILABLE=TRUE (Task 3/B4).
    final nothingWasStored =
        result.totalPdfs > 0 && failedCount == result.totalPdfs;
    state = state.copyWith(
      status: result.hasWarnings
          ? OfflineBulkDownloadStatus.completedWithWarnings
          : OfflineBulkDownloadStatus.completed,
      progress: null,
      clearCheckpoint: true,
      unmatchedZipEntries: result.unmatchedZipEntries,
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

  /// Pausa bulk em andamento ao ir para background (salva checkpoint via cancel).
  void pauseForBackground() {
    if (!state.isRunning) return;
    _cancelToken?.cancel('app backgrounded');
  }

  void dismissCheckpoint() {
    ref.read(offlineBulkCheckpointStoreProvider).clear();
    state = state.copyWith(clearCheckpoint: true);
  }
}
