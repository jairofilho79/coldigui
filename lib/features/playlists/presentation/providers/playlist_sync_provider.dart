import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/datasources/playlist_remote_datasource.dart';
import '../../data/providers/playlist_providers.dart';
import '../../domain/usecases/sync_playlists.dart';

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

/// Estado de sync em andamento (spinner na tela de listas).
class PlaylistSyncState {
  const PlaylistSyncState({this.isSyncing = false, this.lastResult});

  final bool isSyncing;
  final PlaylistSyncResult? lastResult;

  PlaylistSyncState copyWith({
    bool? isSyncing,
    PlaylistSyncResult? lastResult,
  }) {
    return PlaylistSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastResult: lastResult ?? this.lastResult,
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
        _lastSyncedSub = null;
        return;
      }
      if (_lastSyncedSub == user.googleSub) return;
      _lastSyncedSub = user.googleSub;
      unawaited(syncAfterLogin());
    }, fireImmediately: true);
    return const PlaylistSyncState();
  }

  /// Dispara sync se autenticado. Sem login: no-op (não tenta rede).
  Future<PlaylistSyncResult> sync() async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) {
      return PlaylistSyncResult.skippedAuth;
    }

    final existing = _inFlight;
    if (existing != null) {
      await existing;
      return state.lastResult ?? PlaylistSyncResult.skippedAuth;
    }

    final future = _run(user.idToken);
    _inFlight = future;
    try {
      await future;
      return state.lastResult ?? const PlaylistSyncResult();
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _run(String idToken) async {
    state = state.copyWith(isSyncing: true);
    try {
      final result = await ref.read(syncPlaylistsProvider)(idToken: idToken);
      state = PlaylistSyncState(isSyncing: false, lastResult: result);
    } on Object {
      state = const PlaylistSyncState(isSyncing: false);
    }
  }

  /// Pós-login: marca salvas como pendingPush e sincroniza.
  Future<void> syncAfterLogin() async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    await ref.read(playlistRepositoryProvider).markAllSavedPendingPush();
    await sync();
  }
}
