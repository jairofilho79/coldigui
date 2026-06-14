import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/providers/offline_providers.dart';
import '../../domain/entities/reconcile_result.dart';

/// Estado do reconcile global UC-10 (Fase 3.6).
///
/// Consumido por [offlineCacheStatusProvider] para propagar [lastResult.removedFromIndex].
class OfflineReconcileState {
  const OfflineReconcileState({
    this.lastResult,
    this.lastRunAt,
    this.isRunning = false,
  });

  /// Resultado do último [ReconcileOfflineIndex] concluído.
  final ReconcileResult? lastResult;

  /// Timestamp do último reconcile bem-sucedido.
  final DateTime? lastRunAt;

  /// `true` enquanto [OfflineReconcileNotifier.requestReconcile] executa.
  final bool isRunning;

  OfflineReconcileState copyWith({
    ReconcileResult? lastResult,
    DateTime? lastRunAt,
    bool? isRunning,
  }) {
    return OfflineReconcileState(
      lastResult: lastResult ?? this.lastResult,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      isRunning: isRunning ?? this.isRunning,
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
  Future<void> requestReconcile() async {
    if (state.isRunning) return;

    final lastAt = _loadLastReconcileAt();
    if (lastAt != null &&
        DateTime.now().difference(lastAt) <
            OfflineConfig.reconcileMinInterval) {
      return;
    }

    state = state.copyWith(isRunning: true);

    try {
      await ref.read(migrateOfflineStorageProvider).call();
      final result = await ref.read(reconcileOfflineIndexProvider).call();
      final now = DateTime.now();
      await _persistLastReconcileAt(now);
      state = OfflineReconcileState(
        lastResult: result,
        lastRunAt: now,
      );
    } finally {
      if (state.isRunning) {
        state = state.copyWith(isRunning: false);
      }
    }
  }

  DateTime? _loadLastReconcileAt() {
    final millis =
        ref.read(sharedPreferencesProvider).getInt(StorageKeys.lastReconcileAt);
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
