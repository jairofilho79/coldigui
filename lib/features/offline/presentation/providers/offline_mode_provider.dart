import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/offline_providers.dart';
import 'offline_cache_status_provider.dart';

/// Mínimo de PDFs locais para inferir bulk já concluído (migração pré-flag).
///
/// Ignorado quando [OfflineAvailableStore.isExplicitlyDisabled] (`FALSE` pós-limpar cache).
const int offlineModeMigrationMinPdfCount = 200;

/// UC-09/UC-10 — Gate da UI [OfflineSettingsScreen] (`OFFLINE_AVAILABLE`).
///
/// - `true` — card UC-10 (stats + baixar faltantes + limpar cache).
/// - `false` — card UC-09 (seleção de categorias + bulk).
///
/// Não gateia abertura de PDF (contagem Isar via [offlineCacheStatusProvider]).
final offlineModeProvider = NotifierProvider<OfflineModeNotifier, bool>(
  OfflineModeNotifier.new,
);

/// Notifier Riverpod do gate UC-09 vs UC-10 na tela offline.
class OfflineModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final configured = ref.watch(offlineAvailableStoreProvider).isConfigured;

    ref.listen(offlineCacheStatusProvider, (previous, next) {
      final store = ref.read(offlineAvailableStoreProvider);
      if (state ||
          store.isConfigured ||
          store.isExplicitlyDisabled ||
          next.validCount < offlineModeMigrationMinPdfCount) {
        return;
      }
      unawaited(markConfigured());
    });

    return configured;
  }

  /// Persiste `OFFLINE_AVAILABLE=TRUE` após bulk UC-09 concluído.
  Future<void> markConfigured() async {
    await ref.read(offlineAvailableStoreProvider).markConfigured();
    state = true;
  }

  /// Persiste `OFFLINE_AVAILABLE=FALSE` (uso direto; preferir [ClearOfflineCache]).
  Future<void> clear() async {
    await ref.read(offlineAvailableStoreProvider).clear();
    state = false;
  }

  /// Sincroniza `state = false` após [ClearOfflineCache] (flag já `FALSE` em prefs).
  void syncDisabled() => state = false;
}
