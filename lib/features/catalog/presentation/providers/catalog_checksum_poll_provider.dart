import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/providers/catalog_providers.dart';
import 'louvores_manifest_provider.dart';

/// Estado do poll automático de checksum UC-12.
class CatalogChecksumPollState {
  const CatalogChecksumPollState({
    this.lastPollAt,
    this.isRunning = false,
  });

  /// Timestamp do último poll executado (throttle de 30 min).
  final DateTime? lastPollAt;

  final bool isRunning;

  CatalogChecksumPollState copyWith({
    DateTime? lastPollAt,
    bool? isRunning,
  }) {
    return CatalogChecksumPollState(
      lastPollAt: lastPollAt ?? this.lastPollAt,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

/// Provider de poll automático de checksum UC-12.
///
/// Trigger: [OfflineLifecycleListener] foreground debounced. Máximo 1x / 30 min.
final catalogChecksumPollProvider =
    NotifierProvider<CatalogChecksumPollNotifier, CatalogChecksumPollState>(
  CatalogChecksumPollNotifier.new,
);

/// Dispara [PollManifestChecksum] com throttle e invalida manifest se sincronizado.
class CatalogChecksumPollNotifier extends Notifier<CatalogChecksumPollState> {
  Timer? _debounceTimer;

  @override
  CatalogChecksumPollState build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return const CatalogChecksumPollState();
  }

  /// Poll imediato — respeita throttle e deduplica execução concorrente.
  Future<void> requestPoll() async {
    if (state.isRunning) return;

    final lastPollAt = _loadLastPollAt();
    if (lastPollAt != null &&
        DateTime.now().difference(lastPollAt) <
            OfflineConfig.catalogChecksumPollMinInterval) {
      return;
    }

    state = state.copyWith(isRunning: true);

    try {
      final synced = await ref.read(pollManifestChecksumProvider).call();
      if (synced) {
        ref.invalidate(louvoresManifestProvider);
      }
      final now = DateTime.now();
      await _persistLastPollAt(now);
      state = CatalogChecksumPollState(lastPollAt: now);
    } finally {
      if (state.isRunning) {
        state = state.copyWith(isRunning: false);
      }
    }
  }

  DateTime? _loadLastPollAt() {
    final millis = ref
        .read(sharedPreferencesProvider)
        .getInt(StorageKeys.lastChecksumPollAt);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> _persistLastPollAt(DateTime at) {
    return ref.read(sharedPreferencesProvider).setInt(
          StorageKeys.lastChecksumPollAt,
          at.millisecondsSinceEpoch,
        );
  }

  /// Poll com debounce — usado ao retornar ao foreground.
  void requestPollDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(OfflineConfig.reconcileForegroundDebounce, () {
      unawaited(requestPoll());
    });
  }
}
