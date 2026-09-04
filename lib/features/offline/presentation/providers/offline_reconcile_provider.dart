import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/providers/offline_providers.dart';
import '../../domain/entities/offline_manifest.dart';
import '../../domain/entities/reconcile_result.dart';
import '../../domain/usecases/reconcile_offline_index.dart';
import 'offline_maintenance_lock_provider.dart';

/// Estado do reconcile global UC-10 (Fase 3.6).
///
/// Consumido por [offlineCacheStatusProvider] para propagar [lastResult.removedFromIndex].
class OfflineReconcileState {
  const OfflineReconcileState({
    this.lastResult,
    this.lastRunAt,
    this.isRunning = false,
    this.lastSkipReason,
  });

  /// Resultado do último [ReconcileOfflineIndex] concluído.
  final ReconcileResult? lastResult;

  /// Timestamp do último reconcile bem-sucedido.
  final DateTime? lastRunAt;

  /// `true` enquanto [OfflineReconcileNotifier.requestReconcile] executa.
  final bool isRunning;

  /// Motivo da última recusa (índice indisponível/vazio ou lock ocupado).
  final ReconcileSkipReason? lastSkipReason;

  OfflineReconcileState copyWith({
    ReconcileResult? lastResult,
    DateTime? lastRunAt,
    bool? isRunning,
    ReconcileSkipReason? lastSkipReason,
    bool clearSkipReason = false,
  }) {
    return OfflineReconcileState(
      lastResult: lastResult ?? this.lastResult,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      isRunning: isRunning ?? this.isRunning,
      lastSkipReason: clearSkipReason
          ? null
          : (lastSkipReason ?? this.lastSkipReason),
    );
  }
}

/// Provider de reconcile global UC-10 (Fase 3.6).
///
/// Triggers: init [OfflineSettingsScreen], [OfflineLifecycleListener] foreground
/// debounced. **Proibido** no cold start / `main()`.
final offlineReconcileProvider =
    NotifierProvider<OfflineReconcileNotifier, OfflineReconcileState>(
      OfflineReconcileNotifier.new,
    );

/// Dispara [MigrateOfflineStorage] + [ReconcileOfflineIndex] em background.
class OfflineReconcileNotifier extends Notifier<OfflineReconcileState> {
  Timer? _debounceTimer;

  @override
  OfflineReconcileState build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return const OfflineReconcileState();
  }

  /// Reconcile imediato — deduplica se já em execução ou throttle recente.
  ///
  /// Com [materialPackage]/[materialCategory] roda **escopado** (usado pelo
  /// bulk ao concluir), sem throttle e sem persistir `lastReconcileAt`.
  Future<void> requestReconcile({
    OfflineMaterialPackage? materialPackage,
    String? materialCategory,
  }) async {
    if (state.isRunning) return;

    final isScoped = materialPackage != null;
    if (!isScoped) {
      final lastAt = _loadLastReconcileAt();
      if (lastAt != null &&
          DateTime.now().difference(lastAt) <
              OfflineConfig.reconcileMinInterval) {
        return;
      }
    }

    final lock = ref.read(offlineMaintenanceLockProvider.notifier);
    if (!lock.tryAcquire(OfflineMaintenanceOwner.reconcile)) {
      debugPrint('[offline] reconcile adiado: manutenção offline em andamento');
      state = state.copyWith(lastSkipReason: ReconcileSkipReason.locked);
      return;
    }

    state = state.copyWith(isRunning: true, clearSkipReason: true);

    try {
      await ref.read(migrateOfflineStorageProvider).call();
      final outcome = await ref
          .read(reconcileOfflineIndexProvider)
          .call(
            materialPackage: materialPackage,
            materialCategory: materialCategory,
            isIndexAvailable: ref.read(isarAvailableProvider),
          );

      switch (outcome) {
        case ReconcileDone():
          final now = DateTime.now();
          if (!isScoped) {
            await _persistLastReconcileAt(now);
          }
          state = OfflineReconcileState(
            lastResult: outcome.result,
            lastRunAt: now,
          );
        case ReconcileSkipped(:final reason):
          state = state.copyWith(lastSkipReason: reason);
      }
    } on StorageUnavailableException catch (e) {
      debugPrint('[offline] reconcile abortado: $e');
      state = state.copyWith(
        lastSkipReason: ReconcileSkipReason.indexUnavailable,
      );
    } finally {
      lock.release(OfflineMaintenanceOwner.reconcile);
      if (state.isRunning) {
        state = state.copyWith(isRunning: false);
      }
    }
  }

  DateTime? _loadLastReconcileAt() {
    final millis = ref
        .read(sharedPreferencesProvider)
        .getInt(StorageKeys.lastReconcileAt);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> _persistLastReconcileAt(DateTime at) {
    return ref
        .read(sharedPreferencesProvider)
        .setInt(StorageKeys.lastReconcileAt, at.millisecondsSinceEpoch);
  }

  /// Reconcile com debounce — usado ao retornar ao foreground.
  void requestReconcileDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(OfflineConfig.reconcileForegroundDebounce, () {
      unawaited(requestReconcile());
    });
  }
}
