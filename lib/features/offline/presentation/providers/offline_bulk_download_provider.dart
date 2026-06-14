import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/offline_providers.dart';
import 'offline_cache_status_provider.dart';
import 'offline_mode_provider.dart';
import '../../domain/entities/offline_bulk_checkpoint.dart';
import '../../domain/entities/offline_download_progress.dart';
import '../../domain/exceptions/offline_bulk_exceptions.dart';
import '../../domain/usecases/download_offline_packages.dart';

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

  @override
  OfflineBulkDownloadState build() {
    ref.onDispose(() => _cancelToken?.cancel());

    Future.microtask(_loadCheckpoint);

    return const OfflineBulkDownloadState();
  }

  Future<void> _loadCheckpoint() async {
    final checkpoint =
        await ref.read(offlineBulkCheckpointStoreProvider).load();
    if (checkpoint != null) {
      state = state.copyWith(checkpoint: checkpoint);
    }
  }

  Future<void> start(List<String> categories) async {
    if (state.isRunning) return;

    _cancelToken = CancelToken();
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.running,
      clearError: true,
      clearCheckpoint: true,
      clearUnmatchedZipEntries: true,
    );

    try {
      final result = await ref.read(downloadOfflinePackagesProvider).call(
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
      final checkpoint =
          await ref.read(offlineBulkCheckpointStoreProvider).load();
      state = state.copyWith(
        status: OfflineBulkDownloadStatus.cancelled,
        checkpoint: checkpoint,
        progress: null,
      );
    } on InsufficientDiskSpaceException {
      state = state.copyWith(
        status: OfflineBulkDownloadStatus.failed,
        errorMessage: 'offlineInsufficientDiskSpace',
        progress: null,
      );
    } on Object catch (_) {
      final checkpoint =
          await ref.read(offlineBulkCheckpointStoreProvider).load();
      state = state.copyWith(
        status: OfflineBulkDownloadStatus.failed,
        errorMessage: 'offlineDownloadError',
        checkpoint: checkpoint,
        progress: null,
      );
    }
  }

  Future<void> resumeFromCheckpoint() async {
    final checkpoint = state.checkpoint ??
        await ref.read(offlineBulkCheckpointStoreProvider).load();
    if (checkpoint == null) return;

    _cancelToken = CancelToken();
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.running,
      clearError: true,
    );

    try {
      final result = await ref.read(downloadOfflinePackagesProvider).call(
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
      final saved = await ref.read(offlineBulkCheckpointStoreProvider).load();
      state = state.copyWith(
        status: OfflineBulkDownloadStatus.cancelled,
        checkpoint: saved,
        progress: null,
      );
    } on Object catch (_) {
      final saved = await ref.read(offlineBulkCheckpointStoreProvider).load();
      state = state.copyWith(
        status: OfflineBulkDownloadStatus.failed,
        errorMessage: 'offlineDownloadError',
        checkpoint: saved,
        progress: null,
      );
    }
  }

  Future<void> _completeBulkDownload(
      DownloadOfflinePackagesResult result) async {
    state = state.copyWith(
      status: result.hasWarnings
          ? OfflineBulkDownloadStatus.completedWithWarnings
          : OfflineBulkDownloadStatus.completed,
      progress: null,
      clearCheckpoint: true,
      unmatchedZipEntries: result.unmatchedZipEntries,
    );
    await ref.read(offlineModeProvider.notifier).markConfigured();
    await ref.read(offlineCacheStatusProvider.notifier).refresh();
  }

  void cancel() {
    _cancelToken?.cancel('cancelled by user');
  }

  void dismissCheckpoint() {
    ref.read(offlineBulkCheckpointStoreProvider).clear();
    state = state.copyWith(clearCheckpoint: true);
  }
}
