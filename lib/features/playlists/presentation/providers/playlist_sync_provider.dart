import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/datasources/playlist_remote_datasource.dart';
import '../../data/providers/playlist_providers.dart';
import '../../domain/usecases/sync_playlists.dart';
import 'active_playlist_provider.dart';
import 'playlist_sync_lifecycle.dart';
import 'playlists_provider.dart';

/// Último `sub` que passou pelo `syncAfterLogin` — persistido para o boot com a
/// mesma conta não remarcar tudo como `pendingPush` (spec A.7).
const String kLastSyncedSubKey = 'playlist_sync.last_synced_sub';

final playlistRemoteDatasourceProvider = Provider<PlaylistRemoteDatasource>((
  ref,
) {
  return PlaylistRemoteDatasource(ref.watch(dioProvider));
});

final syncPlaylistsProvider = Provider<SyncPlaylists>((ref) {
  final remote = ref.watch(playlistRemoteDatasourceProvider);
  return SyncPlaylists(
    ref.watch(playlistRepositoryProvider),
    remote.fetchAll,
    ({required idToken, required playlist}) =>
        remote.upsert(idToken: idToken, playlist: playlist),
    ({required idToken, required playlistId}) =>
        remote.softDelete(idToken: idToken, playlistId: playlistId),
  );
});

/// Estado de sync em andamento (spinner na tela de listas) e do que deu errado.
class PlaylistSyncState {
  const PlaylistSyncState({
    this.isSyncing = false,
    this.lastResult,
    this.lastErrorCause,
    this.conflicts = 0,
    this.conflictCopies = const [],
    this.deletedRemotely = 0,
  });

  final bool isSyncing;
  final PlaylistSyncResult? lastResult;

  /// Erro **cru** da última tentativa, ou `null` se ela foi limpa.
  ///
  /// Cru porque o notifier não tem `BuildContext`: quem traduz é o banner, com
  /// `userMessageFor(l10n, cause)`.
  final Object? lastErrorCause;

  /// Listas que ficaram em conflito na última rodada.
  final int conflicts;

  /// Nomes das cópias que guardaram edições locais num `409` (spec A.3).
  final List<String> conflictCopies;

  /// Listas apagadas aqui porque sumiram em outro aparelho (spec A.2).
  ///
  /// Não é problema — vira snackbar informativo, não banner.
  final int deletedRemotely;

  /// `true` quando há algo a mostrar ao usuário na tela de listas.
  bool get hasProblem =>
      lastErrorCause != null || conflicts > 0 || conflictCopies.isNotEmpty;

  /// Sem `clearError`: quem limpa o erro é a sync que deu certo, montando um
  /// [PlaylistSyncState] novo — não há caso de apagar o erro sem outra rodada.
  PlaylistSyncState copyWith({
    bool? isSyncing,
    PlaylistSyncResult? lastResult,
    Object? lastErrorCause,
    int? conflicts,
    List<String>? conflictCopies,
    int? deletedRemotely,
  }) {
    return PlaylistSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastResult: lastResult ?? this.lastResult,
      lastErrorCause: lastErrorCause ?? this.lastErrorCause,
      conflicts: conflicts ?? this.conflicts,
      conflictCopies: conflictCopies ?? this.conflictCopies,
      deletedRemotely: deletedRemotely ?? this.deletedRemotely,
    );
  }
}

final playlistSyncProvider =
    NotifierProvider<PlaylistSyncNotifier, PlaylistSyncState>(
      PlaylistSyncNotifier.new,
    );

class PlaylistSyncNotifier extends Notifier<PlaylistSyncState> {
  Future<void>? _inFlight;
  String? _lastSyncedSub;

  @override
  PlaylistSyncState build() {
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
    return const PlaylistSyncState();
  }

  /// Sync do boot/login: só remarca tudo como `pendingPush` quando a conta
  /// mudou desde a última vez (o `sub` persistido).
  Future<void> _syncForCurrentSub() async {
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
      debugPrint('[playlists] sync pós-login falhou: $e');
    }
  }

  /// Dispara sync se autenticado. Sem login (ou já descartado): no-op.
  Future<PlaylistSyncResult> sync() async {
    if (!ref.mounted) return PlaylistSyncResult.skippedAuth;
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) {
      return PlaylistSyncResult.skippedAuth;
    }

    final existing = _inFlight;
    if (existing != null) {
      await existing;
      return state.lastResult ?? PlaylistSyncResult.skippedAuth;
    }

    final future = _run(user.idToken, user.googleSub);
    _inFlight = future;
    try {
      await future;
      return state.lastResult ?? const PlaylistSyncResult();
    } finally {
      _inFlight = null;
    }
  }

  /// "Tentar novamente" do banner: sincroniza e recarrega a lista visível se
  /// alguma linha se mexeu.
  ///
  /// Mora no notifier, e não no widget, porque o `WidgetRef` do banner não tem
  /// `mounted`: sair da tela no meio do retry faria o `read` de depois do
  /// `await` explodir num callback sem dono. O `Ref` daqui tem.
  ///
  /// A regra de recarregar é a mesma do [PlaylistSyncLifecycleMixin]:
  /// `PlaylistsNotifier` não observa o banco, então uma sync que trouxe listas
  /// novas apagaria o banner e deixaria a tela mostrando o estado velho.
  Future<void> retryAndReload() async {
    final result = await sync();
    if (!ref.mounted || result.skipped) return;
    if (result.pulled == 0 &&
        result.pushed == 0 &&
        result.deleted == 0 &&
        result.deletedRemotely == 0) {
      return;
    }
    await ref.read(playlistsProvider.notifier).reload();
  }

  Future<void> _run(String idToken, String? sub) async {
    state = state.copyWith(isSyncing: true);
    try {
      final result = await ref.read(syncPlaylistsProvider)(
        idToken: idToken,
        sub: sub,
      );
      if (!ref.mounted) return;
      // O resultado carrega os erros tolerados (pull caiu, push falhou): eles
      // valem banner mesmo com a sync tendo terminado.
      state = PlaylistSyncState(
        isSyncing: false,
        lastResult: result,
        lastErrorCause: result.error,
        conflicts: result.conflicts,
        conflictCopies: result.conflictCopies,
        deletedRemotely: result.deletedRemotely,
      );
      // Uma lista apagada em outro aparelho pode ser justamente a ativa: o
      // carousel ficaria espelhando um id que não existe mais (spec A.2).
      if (result.deletedRemotely > 0) {
        await _clearActiveIfGone();
      }
    } on Object catch (e) {
      debugPrint('[playlists] sync falhou: $e');
      if (!ref.mounted) return;
      state = PlaylistSyncState(isSyncing: false, lastErrorCause: e);
    }
  }

  /// Limpa o id ativo se a lista que ele aponta não existe mais.
  ///
  /// Erro próprio: o id ativo é conforto de navegação, e uma
  /// SharedPreferences/Isar indisponível aqui não pode transformar uma sync que
  /// deu certo num banner de falha.
  Future<void> _clearActiveIfGone() async {
    if (!ref.mounted) return;
    try {
      final activeId = ref.read(activePlaylistIdProvider);
      if (activeId == null) return;
      final existing = await ref
          .read(playlistRepositoryProvider)
          .getById(activeId);
      if (!ref.mounted || existing != null) return;
      ref.read(activePlaylistIdProvider.notifier).clear();
      debugPrint('[playlists] lista ativa $activeId sumiu: id ativo limpo');
    } on Object catch (e) {
      debugPrint('[playlists] não deu para revisar a lista ativa: $e');
    }
  }

  /// Pós-login: adota as listas para a conta que entrou e sincroniza.
  ///
  /// Só roda de verdade quando o `sub` muda (ver [build]). Na troca de conta, a
  /// purga da anterior vem **antes** da adoção: as listas `synced` do dono
  /// antigo já estão na nuvem dele e não podem subir para a conta nova
  /// (spec A.5) — e se a purga levou a lista ativa, o id ativo é limpo.
  ///
  /// Uma falha de armazenamento aqui vira [PlaylistSyncState.lastErrorCause] em
  /// vez de um erro não tratado na zona do login — e o `sub` **não** é
  /// persistido, para a próxima tentativa repetir a adoção.
  Future<void> syncAfterLogin() async {
    if (!ref.mounted) return;
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    final previous = _persistedSub();
    try {
      final repository = ref.read(playlistRepositoryProvider);
      if (previous != null && previous != user.googleSub) {
        final purged = await repository.purgeSyncedOwnedBy(previous);
        if (!ref.mounted) return;
        debugPrint('[playlists] $purged lista(s) de $previous removidas');
        await _clearActiveIfGone();
        if (!ref.mounted) return;
      }
      await repository.adoptForSub(user.googleSub);
    } on Object catch (e) {
      debugPrint('[playlists] adoptForSub falhou: $e');
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
      debugPrint('[playlists] SharedPreferences indisponível para o sync: $e');
      return null;
    }
  }

  String? _persistedSub() => _prefs?.getString(kLastSyncedSubKey);

  Future<void> _persistSub(String sub) async {
    try {
      await _prefs?.setString(kLastSyncedSubKey, sub);
    } on Object catch (e) {
      debugPrint('[playlists] não deu para guardar o sub do sync: $e');
    }
  }
}
