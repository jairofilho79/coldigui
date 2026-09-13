import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/providers/material_kind_prefs_providers.dart';
import '../../domain/usecases/sync_material_kind_prefs.dart';
import 'material_kind_prefs_provider.dart';

// Reexporta o resultado/outcome da sync: quem observa este provider (tela,
// testes) não precisa importar o usecase separadamente para checar o
// resultado de `sync()`.
export '../../domain/usecases/sync_material_kind_prefs.dart'
    show MaterialKindPrefsSyncOutcome, MaterialKindPrefsSyncResult;

class MaterialKindPrefsSyncState {
  const MaterialKindPrefsSyncState({
    this.isSyncing = false,
    this.lastResult,
    this.lastErrorCause,
  });

  final bool isSyncing;
  final MaterialKindPrefsSyncResult? lastResult;

  /// Erro cru da última tentativa; quem traduz é a tela (`userMessageFor`).
  final Object? lastErrorCause;

  MaterialKindPrefsSyncState copyWith({
    bool? isSyncing,
    MaterialKindPrefsSyncResult? lastResult,
    Object? lastErrorCause,
  }) {
    return MaterialKindPrefsSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastResult: lastResult ?? this.lastResult,
      lastErrorCause: lastErrorCause ?? this.lastErrorCause,
    );
  }
}

/// Orquestra a sync dos favoritos: login com `sub` novo, volta da rede
/// (debounce) e `sync()` explícito após cada `save`.
///
/// Versão enxuta do `AudioFlagSyncNotifier`: sem adoção/purga porque o
/// documento já é por conta (chave = `sub`).
final materialKindPrefsSyncProvider =
    NotifierProvider<MaterialKindPrefsSyncNotifier, MaterialKindPrefsSyncState>(
      MaterialKindPrefsSyncNotifier.new,
    );

class MaterialKindPrefsSyncNotifier
    extends Notifier<MaterialKindPrefsSyncState> {
  static Duration reconnectDebounce = const Duration(seconds: 2);

  Future<MaterialKindPrefsSyncResult>? _inFlight;

  /// `sync()` chegou com uma rodada em voo: ela já leu o local e não vai ver
  /// o que foi salvo depois, então uma rodada extra fica agendada para o
  /// `finally` — uma só, por mais pedidos que cheguem nesse meio-tempo.
  bool _rerunRequested = false;
  String? _lastSyncedSub;
  Timer? _reconnectTimer;

  @override
  MaterialKindPrefsSyncState build() {
    ref.onDispose(() {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    });

    ref.listen(authStateProvider, (prev, next) {
      final user = next.asData?.value;
      if (user == null) {
        _lastSyncedSub = null;
        return;
      }
      if (_lastSyncedSub == user.googleSub) return;
      _lastSyncedSub = user.googleSub;
      unawaited(Future<void>.microtask(() => sync()));
    }, fireImmediately: true);

    ref.listen(connectivityStreamProvider, (prev, next) {
      final online = next.asData?.value ?? false;
      final wasOnline = prev?.asData?.value ?? false;
      if (!online || wasOnline) return;
      if (ref.read(authStateProvider).asData?.value == null) return;
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(reconnectDebounce, () {
        if (!ref.mounted) return;
        unawaited(sync());
      });
    });

    return const MaterialKindPrefsSyncState();
  }

  Future<MaterialKindPrefsSyncResult> sync() async {
    if (!ref.mounted) return MaterialKindPrefsSyncResult.skippedAuth;
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return MaterialKindPrefsSyncResult.skippedAuth;

    final existing = _inFlight;
    if (existing != null) {
      _rerunRequested = true;
      return existing;
    }

    final future = _run(user.idToken, user.googleSub);
    _inFlight = future;
    try {
      return await future;
    } finally {
      _inFlight = null;
      if (_rerunRequested) {
        _rerunRequested = false;
        // Coalesce em vez de descartar: sem isso, um `save` durante a rodada
        // ficaria `pendingPush` até o próximo login ou volta da rede.
        unawaited(sync());
      }
    }
  }

  Future<MaterialKindPrefsSyncResult> _run(String idToken, String sub) async {
    state = state.copyWith(isSyncing: true);
    try {
      final result = await ref.read(syncMaterialKindPrefsProvider)(
        idToken: idToken,
        sub: sub,
      );
      if (!ref.mounted) return result;
      state = MaterialKindPrefsSyncState(
        isSyncing: false,
        lastResult: result,
        lastErrorCause: result.error,
      );
      if (result.changedLocal) ref.invalidate(materialKindPrefsProvider);
      return result;
    } on Object catch (e) {
      debugPrint('[material-kind-prefs] sync falhou: $e');
      if (ref.mounted) {
        state = MaterialKindPrefsSyncState(isSyncing: false, lastErrorCause: e);
      }
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.noop,
        pushError: e,
      );
    }
  }
}
