import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/offline_providers.dart';
import '../../data/utils/storage_quota_estimator.dart';
import 'offline_reconcile_provider.dart';

/// Uso de disco do offline e aviso pós-reconcile para o `/offline`.
class OfflineCacheStatus {
  const OfflineCacheStatus({
    this.diskUsageBytes = 0,
    this.removedCount = 0,
    this.isRefreshing = false,
    this.freeDiskBytes,
  });

  static const empty = OfflineCacheStatus();

  /// Bytes dos PDFs offline no store (scan real — `getTotalOfflineBytes`).
  final int diskUsageBytes;

  /// Bytes livres no volume de armazenamento (`null` se indisponível).
  final int? freeDiskBytes;

  /// PDFs removidos do índice no último reconcile (banner no `/offline`).
  final int removedCount;

  /// `true` enquanto [OfflineCacheStatusNotifier.refresh] está em execução.
  final bool isRefreshing;

  /// Exibir banner de PDFs removidos externamente.
  bool get showRemovedWarning => removedCount > 0;

  OfflineCacheStatus copyWith({
    int? diskUsageBytes,
    int? removedCount,
    bool? isRefreshing,
    int? freeDiskBytes,
  }) {
    return OfflineCacheStatus(
      diskUsageBytes: diskUsageBytes ?? this.diskUsageBytes,
      removedCount: removedCount ?? this.removedCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      freeDiskBytes: freeDiskBytes ?? this.freeDiskBytes,
    );
  }
}

/// Provider do uso de disco offline para a UI (Fase 3.7).
///
/// Cold start: carrega via microtask — **sem** reconcile no boot. Listener em
/// [offlineReconcileProvider] propaga `removedFromIndex`.
final offlineCacheStatusProvider =
    NotifierProvider<OfflineCacheStatusNotifier, OfflineCacheStatus>(
      OfflineCacheStatusNotifier.new,
    );

class OfflineCacheStatusNotifier extends Notifier<OfflineCacheStatus> {
  @override
  OfflineCacheStatus build() {
    ref.listen(offlineReconcileProvider, (previous, next) {
      final wasRunning = previous?.isRunning ?? false;
      if (wasRunning && !next.isRunning) {
        unawaited(refresh(removedCount: _removedFromLastReconcile(next)));
      }
    });

    Future.microtask(refresh);
    return OfflineCacheStatus.empty;
  }

  Future<OfflineCacheStatus> _read({required int removedCount}) async {
    final used = await ref.read(pdfStoragePortProvider).getTotalOfflineBytes();
    final free = await estimateFreeStorageBytes();
    return OfflineCacheStatus(
      diskUsageBytes: used,
      removedCount: removedCount,
      freeDiskBytes: free,
    );
  }

  /// Relê o uso de disco. [removedCount] opcional após reconcile.
  Future<void> refresh({int? removedCount}) async {
    final preserved = removedCount ?? state.removedCount;
    state = state.copyWith(isRefreshing: true);
    try {
      state = await _read(removedCount: preserved);
    } finally {
      if (state.isRefreshing) state = state.copyWith(isRefreshing: false);
    }
  }

  /// Reconcile índice vs disco e relê o uso de disco (UC-10 UI).
  Future<void> refreshAll() async {
    state = state.copyWith(isRefreshing: true);
    try {
      await ref.read(offlineReconcileProvider.notifier).requestReconcile();
      state = await _read(
        removedCount: _removedFromLastReconcile(
          ref.read(offlineReconcileProvider),
        ),
      );
    } finally {
      if (state.isRefreshing) state = state.copyWith(isRefreshing: false);
    }
  }

  /// `removedFromIndex` só vale quando o reconcile de fato rodou: se foi
  /// pulado (lock ocupado, índice indisponível/vazio), o `lastResult` é de
  /// uma execução anterior e não descreve esta rodada (fix round 1).
  static int _removedFromLastReconcile(OfflineReconcileState reconcile) {
    if (reconcile.lastSkipReason != null) return 0;
    return reconcile.lastResult?.removedFromIndex ?? 0;
  }

  /// Oculta o banner de PDFs removidos sem alterar o índice Isar.
  void dismissRemovedWarning() {
    if (state.removedCount == 0) return;
    state = state.copyWith(removedCount: 0);
  }
}
