import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/offline_providers.dart';
import '../../domain/entities/offline_stats.dart';
import 'offline_reconcile_provider.dart';

/// Estado agregado do cache offline para UI (Fase 3.7).
///
/// [stats.byCategory] agrega por material de UI; [stats.missingByCategory]
/// vem do manifest remoto após refresh.
class OfflineCacheStatus {
  const OfflineCacheStatus({
    required this.stats,
    this.removedCount = 0,
    this.isRefreshing = false,
    this.freeDiskBytes,
  });

  static const empty = OfflineCacheStatus(stats: OfflineStats(byCategory: {}));

  final OfflineStats stats;

  /// Bytes livres no volume de armazenamento (`null` se indisponível).
  final int? freeDiskBytes;

  /// PDFs removidos do índice no último reconcile (aviso na [OfflineSettingsScreen]).
  final int removedCount;

  /// `true` enquanto [OfflineCacheStatusNotifier.refresh] está em execução.
  final bool isRefreshing;

  /// Total de PDFs offline por material de UI.
  int get validCount => stats.totalCount;

  /// Há cache offline utilizável (≥1 PDF indexado válido).
  bool get isReady => validCount > 0;

  /// Exibir banner de PDFs removidos externamente.
  bool get showRemovedWarning => removedCount > 0;

  OfflineCacheStatus copyWith({
    OfflineStats? stats,
    int? removedCount,
    bool? isRefreshing,
    int? freeDiskBytes,
    bool clearFreeDiskBytes = false,
  }) {
    return OfflineCacheStatus(
      stats: stats ?? this.stats,
      removedCount: removedCount ?? this.removedCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      freeDiskBytes: clearFreeDiskBytes
          ? null
          : (freeDiskBytes ?? this.freeDiskBytes),
    );
  }
}

/// Provider de status do cache offline para UI (Fase 3.7).
///
/// Cold start: carrega stats via microtask — **sem** reconcile no boot.
/// Listener em [offlineReconcileProvider] propaga `removedFromIndex`.
final offlineCacheStatusProvider =
    NotifierProvider<OfflineCacheStatusNotifier, OfflineCacheStatus>(
      OfflineCacheStatusNotifier.new,
    );

/// Expõe contagem Isar e aviso pós-reconcile para
/// [OfflineSettingsScreen].
class OfflineCacheStatusNotifier extends Notifier<OfflineCacheStatus> {
  @override
  OfflineCacheStatus build() {
    ref.listen(offlineReconcileProvider, (previous, next) {
      final wasRunning = previous?.isRunning ?? false;
      if (wasRunning && !next.isRunning) {
        final removed = next.lastResult?.removedFromIndex ?? 0;
        unawaited(refresh(removedCount: removed));
      }
    });

    Future.microtask(refresh);
    return OfflineCacheStatus.empty;
  }

  /// Recarrega stats do índice Isar. [removedCount] opcional após reconcile.
  Future<void> refresh({int? removedCount}) async {
    final preservedRemovedCount = removedCount ?? state.removedCount;
    state = state.copyWith(isRefreshing: true);

    try {
      final stats = await ref.read(getOfflineStatsByCategoryProvider).call();
      state = OfflineCacheStatus(
        stats: stats,
        removedCount: preservedRemovedCount,
      );
    } finally {
      if (state.isRefreshing) {
        state = state.copyWith(isRefreshing: false);
      }
    }
  }

  /// Reconcile índice vs disco e recarrega stats + faltantes (UC-10 UI).
  Future<void> refreshAll() async {
    state = state.copyWith(isRefreshing: true);

    try {
      await ref.read(offlineReconcileProvider.notifier).requestReconcile();
      final removed =
          ref.read(offlineReconcileProvider).lastResult?.removedFromIndex ?? 0;
      final stats = await ref.read(getOfflineStatsByCategoryProvider).call();
      state = OfflineCacheStatus(stats: stats, removedCount: removed);
    } finally {
      if (state.isRefreshing) {
        state = state.copyWith(isRefreshing: false);
      }
    }
  }

  /// Oculta o banner de PDFs removidos sem alterar o índice Isar.
  void dismissRemovedWarning() {
    if (state.removedCount == 0) return;
    state = state.copyWith(removedCount: 0);
  }
}
