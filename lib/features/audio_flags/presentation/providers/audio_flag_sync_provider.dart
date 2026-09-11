import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/providers/audio_flag_providers.dart';
import '../../domain/usecases/sync_audio_flags.dart';
import 'audio_flags_for_track_provider.dart';

/// Último `sub` que passou pela adoção — persistido para o boot com a mesma
/// conta não remarcar tudo como `pendingPush` (spec A.4).
const String kAudioFlagLastSyncedSubKey = 'audio_flag_sync.last_synced_sub';

/// Estado de sync em andamento e do que deu errado (spec A.4).
class AudioFlagSyncState {
  const AudioFlagSyncState({
    this.isSyncing = false,
    this.lastResult,
    this.lastErrorCause,
    this.conflicts = 0,
  });

  final bool isSyncing;
  final AudioFlagSyncResult? lastResult;

  /// Erro **cru** da última tentativa, ou `null` se ela foi limpa.
  ///
  /// Cru porque o notifier não tem `BuildContext`: quem traduz é a linha de
  /// erro do player, com `userMessageFor(l10n, cause)`.
  final Object? lastErrorCause;

  /// Marcadores que ficaram em conflito na última rodada.
  final int conflicts;

  /// `true` quando há algo a mostrar ao usuário no player.
  bool get hasProblem => lastErrorCause != null || conflicts > 0;

  /// Sem `clearError`: quem limpa o erro é a sync que deu certo, montando um
  /// [AudioFlagSyncState] novo.
  AudioFlagSyncState copyWith({
    bool? isSyncing,
    AudioFlagSyncResult? lastResult,
    Object? lastErrorCause,
    int? conflicts,
  }) {
    return AudioFlagSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastResult: lastResult ?? this.lastResult,
      lastErrorCause: lastErrorCause ?? this.lastErrorCause,
      conflicts: conflicts ?? this.conflicts,
    );
  }
}

final audioFlagSyncProvider =
    NotifierProvider<AudioFlagSyncNotifier, AudioFlagSyncState>(
      AudioFlagSyncNotifier.new,
    );

class AudioFlagSyncNotifier extends Notifier<AudioFlagSyncState> {
  /// Espera antes de sincronizar quando a rede volta.
  ///
  /// Mutável e estática só para o teste encolher: a volta da conectividade
  /// costuma vir em rajada (várias mudanças de interface em sequência) e
  /// sincronizar na primeira gastaria uma requisição que ainda falharia.
  static Duration reconnectDebounce = const Duration(seconds: 2);

  Future<void>? _inFlight;
  String? _lastSyncedSub;
  Timer? _reconnectTimer;

  @override
  AudioFlagSyncState build() {
    ref.onDispose(() {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    });

    ref.listen(authStateProvider, (prev, next) {
      final user = next.asData?.value;
      if (user == null) {
        // Só a memória: a chave persistida é o histórico da última conta e
        // sobrevive ao logout, para o re-login na mesma conta ser barato.
        _lastSyncedSub = null;
        return;
      }
      if (_lastSyncedSub == user.googleSub) return;
      _lastSyncedSub = user.googleSub;
      // `fireImmediately` dispara **dentro** do `build`: tocar em `state` daqui
      // leria um provider ainda não inicializado. Sai do build primeiro.
      unawaited(Future<void>.microtask(_syncForCurrentSub));
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

    return const AudioFlagSyncState();
  }

  /// Sync do boot/login: só readota tudo quando a conta mudou desde a última
  /// vez (o `sub` persistido).
  Future<void> _syncForCurrentSub() async {
    if (!ref.mounted) return;
    if (ref.read(authStateProvider).asData?.value == null) return;
    // O app monta enquanto o Isar ainda está abrindo (D.2). Sincronizar antes
    // disso faria `adoptForSub`/`purgeSyncedOwnedBy` verem um datasource
    // degradado — e a adoção que não rodou seria persistida como feita.
    try {
      await ref.read(isarInitializerProvider.future);
    } on Object catch (e) {
      // Modo degradado: segue mesmo assim — quem reclama é o repositório, com
      // `StorageUnavailableException`, e o tratamento de sempre vale.
      debugPrint('[audio-flags] Isar indisponível para o sync pós-login: $e');
    }
    if (!ref.mounted) return;
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    try {
      if (_persistedSub() == user.googleSub) {
        await sync();
      } else {
        await syncAfterLogin();
      }
    } on Object catch (e) {
      debugPrint('[audio-flags] sync pós-login falhou: $e');
    }
  }

  /// Dispara sync se autenticado. Sem login (ou já descartado): no-op.
  Future<AudioFlagSyncResult> sync() async {
    if (!ref.mounted) return AudioFlagSyncResult.skippedAuth;
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) {
      return AudioFlagSyncResult.skippedAuth;
    }

    // `state` também é `ref`: lê-lo depois do `await` num notifier já
    // descartado (o player saiu, ou o container do teste caiu no meio da
    // rodada) lançaria de dentro de um callback sem dono. Sem notifier não há
    // resultado a reportar — quem chamou já checa `skipped`.
    final existing = _inFlight;
    if (existing != null) {
      await existing;
      if (!ref.mounted) return AudioFlagSyncResult.skippedAuth;
      return state.lastResult ?? AudioFlagSyncResult.skippedAuth;
    }

    final future = _run(user.idToken, user.googleSub);
    _inFlight = future;
    try {
      await future;
      if (!ref.mounted) return AudioFlagSyncResult.skippedAuth;
      return state.lastResult ?? const AudioFlagSyncResult();
    } finally {
      _inFlight = null;
    }
  }

  /// "Tentar novamente" da linha de erro do player.
  ///
  /// Mora no notifier, e não no widget, porque o `WidgetRef` da linha não tem
  /// `mounted`: sair da tela no meio do retry faria o `read` de depois do
  /// `await` explodir num callback sem dono. O `Ref` daqui tem.
  ///
  /// Quando o `sub` corrente ainda não foi persistido, a adoção do pós-login
  /// não deu certo — refazê-la é o retry certo (spec A.6); um `sync()` puro
  /// deixaria os marcadores locais sem dono e sem subir.
  Future<void> retryAndReload() async {
    if (!ref.mounted) return;
    final user = ref.read(authStateProvider).asData?.value;
    if (user != null && _persistedSub() != user.googleSub) {
      await syncAfterLogin();
      return;
    }
    await sync();
  }

  Future<void> _run(String idToken, String sub) async {
    state = state.copyWith(isSyncing: true);
    try {
      final result = await ref.read(syncAudioFlagsProvider)(
        idToken: idToken,
        sub: sub,
      );
      if (!ref.mounted) return;
      // O resultado carrega os erros tolerados (pull caiu, push falhou): eles
      // valem aviso mesmo com a sync tendo terminado.
      state = AudioFlagSyncState(
        isSyncing: false,
        lastResult: result,
        lastErrorCause: result.error,
        conflicts: result.conflicts,
      );
      if (!result.skipped &&
          (result.pulled > 0 ||
              result.pushed > 0 ||
              result.deleted > 0 ||
              result.deletedRemotely > 0)) {
        ref.invalidate(audioFlagsForTrackProvider);
      }
    } on Object catch (e) {
      debugPrint('[audio-flags] sync falhou: $e');
      if (!ref.mounted) return;
      state = AudioFlagSyncState(isSyncing: false, lastErrorCause: e);
    }
  }

  /// Pós-login: adota os marcadores para a conta que entrou e sincroniza.
  ///
  /// Só roda de verdade quando o `sub` muda (ver [build]). Na troca de conta, a
  /// purga da anterior vem **antes** da adoção: as linhas `synced` do dono
  /// antigo já estão na nuvem dele e não podem subir para a conta nova
  /// (spec A.5). Uma falha de armazenamento vira
  /// [AudioFlagSyncState.lastErrorCause] em vez de erro não tratado na zona do
  /// login — e o `sub` **não** é persistido, para a próxima tentativa repetir.
  Future<void> syncAfterLogin() async {
    if (!ref.mounted) return;
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    final previous = _persistedSub();
    try {
      final repository = ref.read(audioFlagRepositoryProvider);
      if (previous != null && previous != user.googleSub) {
        final purged = await repository.purgeSyncedOwnedBy(previous);
        if (!ref.mounted) return;
        debugPrint('[audio-flags] $purged marcador(es) de $previous removidos');
      }
      await repository.adoptForSub(user.googleSub);
    } on Object catch (e) {
      debugPrint('[audio-flags] adoptForSub falhou: $e');
      if (ref.mounted) {
        state = state.copyWith(isSyncing: false, lastErrorCause: e);
      }
      return;
    }
    if (!ref.mounted) return;
    await _persistSub(user.googleSub);
    if (!ref.mounted) return;
    await sync();
  }

  /// SharedPreferences pode não estar disponível (teste sem override, web com
  /// storage bloqueado): sem ela, o sync só perde a memória entre boots.
  SharedPreferences? get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } on Object catch (e) {
      debugPrint('[audio-flags] SharedPreferences indisponível: $e');
      return null;
    }
  }

  String? _persistedSub() => _prefs?.getString(kAudioFlagLastSyncedSubKey);

  Future<void> _persistSub(String sub) async {
    try {
      await _prefs?.setString(kAudioFlagLastSyncedSubKey, sub);
    } on Object catch (e) {
      debugPrint('[audio-flags] não deu para guardar o sub do sync: $e');
    }
  }
}
