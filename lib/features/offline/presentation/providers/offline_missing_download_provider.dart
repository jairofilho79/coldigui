import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/failures/app_failure.dart';
import '../../data/providers/offline_providers.dart';
import '../../domain/usecases/download_missing_pdfs.dart';
import 'offline_cache_status_provider.dart';
import 'offline_category_selection_provider.dart';
import 'offline_maintenance_lock_provider.dart';

/// Estado do download de PDFs faltantes UC-10 na UI (Fase 3.7).
enum OfflineMissingDownloadStatus { idle, running, completed, failed }

/// Progresso e resultado de [DownloadMissingPdfs] na [OfflineSettingsScreen].
class OfflineMissingDownloadState {
  const OfflineMissingDownloadState({
    this.status = OfflineMissingDownloadStatus.idle,
    this.done = 0,
    this.total = 0,
    this.lastResult,
    this.failure,
  });

  final OfflineMissingDownloadStatus status;

  /// PDFs processados nesta execução (baixados + falhas).
  final int done;

  /// Total de PDFs faltantes no escopo — não inclui os já armazenados.
  final int total;

  /// Resultado da última execução concluída — usado pelo snackbar da tela.
  final DownloadMissingResult? lastResult;

  /// Falha classificada (E8) da última execução.
  final AppFailure? failure;

  bool get isRunning => status == OfflineMissingDownloadStatus.running;

  OfflineMissingDownloadState copyWith({
    OfflineMissingDownloadStatus? status,
    int? done,
    int? total,
    DownloadMissingResult? lastResult,
    AppFailure? failure,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return OfflineMissingDownloadState(
      status: status ?? this.status,
      done: done ?? this.done,
      total: total ?? this.total,
      lastResult: clearResult ? null : (lastResult ?? this.lastResult),
      failure: clearError ? null : (failure ?? this.failure),
    );
  }
}

/// Provider de download de PDFs faltantes UC-10 (Fase 3.7).
///
/// Ao concluir: refresh [offlineCacheStatusProvider] e dismiss aviso removidos.
final offlineMissingDownloadProvider =
    NotifierProvider<
      OfflineMissingDownloadNotifier,
      OfflineMissingDownloadState
    >(OfflineMissingDownloadNotifier.new);

/// Orquestra [DownloadMissingPdfs] com progresso na UI.
class OfflineMissingDownloadNotifier
    extends Notifier<OfflineMissingDownloadState> {
  @override
  OfflineMissingDownloadState build() => const OfflineMissingDownloadState();

  /// Compara catálogo Isar com índice e baixa misses via [FetchAndStorePdf].
  ///
  /// Escopo: [OfflineCategorySelectionState.missingScope] (selecionadas ∩ bulk).
  Future<void> start() async {
    if (state.isRunning) return;

    // Spec C.1: sem índice não se baixa um byte.
    if (!ref.read(isarAvailableProvider)) {
      debugPrint('[offline] faltantes abortado: índice offline indisponível');
      state = state.copyWith(
        status: OfflineMissingDownloadStatus.failed,
        failure: const StorageFailure(
          StorageUnavailableException('offline.missing'),
        ),
      );
      return;
    }

    final scope = ref.read(offlineCategorySelectionProvider).missingScope;
    if (scope.isEmpty) return;

    final lock = ref.read(offlineMaintenanceLockProvider.notifier);
    if (!lock.tryAcquire(OfflineMaintenanceOwner.missing)) {
      debugPrint('[offline] faltantes adiado: manutenção offline em andamento');
      return;
    }

    state = const OfflineMissingDownloadState(
      status: OfflineMissingDownloadStatus.running,
    );

    try {
      final result = await ref
          .read(downloadMissingPdfsProvider)
          .call(
            materialCategories: scope,
            onProgress: (done, total) {
              state = state.copyWith(
                status: OfflineMissingDownloadStatus.running,
                done: done,
                total: total,
              );
            },
          );

      state = OfflineMissingDownloadState(
        status: OfflineMissingDownloadStatus.completed,
        done: state.done,
        total: state.total,
        lastResult: result,
      );

      await ref.read(offlineCacheStatusProvider.notifier).refresh();
      ref.read(offlineCacheStatusProvider.notifier).dismissRemovedWarning();
    } on Object catch (e) {
      debugPrint('[offline] faltantes falhou: $e');
      state = state.copyWith(
        status: OfflineMissingDownloadStatus.failed,
        failure: AppFailure.from(e),
      );
    } finally {
      lock.release(OfflineMaintenanceOwner.missing);
    }
  }
}
