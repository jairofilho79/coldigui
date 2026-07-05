import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/providers/offline_bulk_providers.dart';
import '../../data/providers/offline_core_providers.dart';
import 'offline_cache_status_provider.dart';
import 'offline_category_selection_provider.dart';
import 'offline_mode_provider.dart';
import '../../domain/entities/offline_bulk_checkpoint.dart';
import '../../domain/entities/offline_download_progress.dart';
import '../../domain/exceptions/offline_bulk_exceptions.dart';
import '../../domain/usecases/download_offline_packages.dart';

/// Chave l10n para falhas de bulk mapeadas a partir de exceções concretas.
String offlineBulkDownloadErrorKey(Object error) {
  if (error is InsufficientDiskSpaceException) {
    return 'offlineInsufficientDiskSpace';
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
  });

  final OfflineBulkDownloadStatus status;
  final OfflineDownloadProgress? progress;
  final OfflineBulkCheckpoint? checkpoint;
  final String? errorMessage;
  final List<String> unmatchedZipEntries;

  bool get isRunning => status == OfflineBulkDownloadStatus.running;
  bool get hasCheckpoint => checkpoint != null;
  bool get completedWithWarnings =>
      status == OfflineBulkDownloadStatus.completedWithWarnings;

  OfflineBulkDownloadState copyWith({
    OfflineBulkDownloadStatus? status,
    OfflineDownloadProgress? progress,
    OfflineBulkCheckpoint? checkpoint,
    String? errorMessage,
    List<String>? unmatchedZipEntries,
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

    _lastStartedCategories = List<String>.from(categories);
    _cancelToken = CancelToken();
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.running,
      clearError: true,
      clearCheckpoint: true,
      clearUnmatchedZipEntries: true,
    );
    await _acquireWakelock();

    try {
      final result = await ref
          .read(downloadOfflinePackagesProvider)
          .call(
            categories: categories,
            cancelToken: _cancelToken,
            onProgress: (progress) {
              state = state.copyWith(
                status: OfflineBulkDownloadStatus.running,
                progress: progress,
              );
            },
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
    }
  }

  Future<void> resumeFromCheckpoint() async {
    final checkpoint =
        state.checkpoint ??
        await ref.read(offlineBulkCheckpointStoreProvider).load();
    if (checkpoint == null) return;

    _lastStartedCategories = List<String>.from(checkpoint.categories);
    _cancelToken = CancelToken();
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.running,
      clearError: true,
    );
    await _acquireWakelock();

    try {
      final result = await ref
          .read(downloadOfflinePackagesProvider)
          .call(
            categories: checkpoint.categories,
            cancelToken: _cancelToken,
            resumeCheckpoint: checkpoint,
            onProgress: (progress) {
              state = state.copyWith(
                status: OfflineBulkDownloadStatus.running,
                progress: progress,
              );
            },
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
    }
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
    state = state.copyWith(
      status: result.hasWarnings
          ? OfflineBulkDownloadStatus.completedWithWarnings
          : OfflineBulkDownloadStatus.completed,
      progress: null,
      clearCheckpoint: true,
      unmatchedZipEntries: result.unmatchedZipEntries,
    );
    if (_lastStartedCategories.isNotEmpty) {
      await ref
          .read(offlineCategorySelectionProvider.notifier)
          .registerBulkCompleted(_lastStartedCategories);
    }
    _lastStartedCategories = const [];
    await ref.read(offlineModeProvider.notifier).markConfigured();
    await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
  }

  void cancel() {
    _cancelToken?.cancel('cancelled by user');
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
