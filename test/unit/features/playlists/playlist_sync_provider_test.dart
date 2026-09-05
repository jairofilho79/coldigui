import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/remote_playlist.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/sync_playlists.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _subKey = 'playlist_sync.last_synced_sub';

class _LoggedInAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 'sub-1', idToken: 'token');
}

/// Repositório mínimo: só conta `markAllSavedPendingPush` (e pode falhar nele).
class _CountingRepository implements PlaylistRepository {
  _CountingRepository({this.markThrows});

  final Object? markThrows;
  var markCalls = 0;

  @override
  Future<void> markAllSavedPendingPush() async {
    markCalls++;
    final error = markThrows;
    if (error != null) throw error;
  }

  @override
  Future<List<SavedPlaylist>> getAll() async => const [];

  @override
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab) async => const [];

  @override
  Future<SavedPlaylist?> getById(String playlistId) async => null;

  @override
  Future<List<SavedPlaylist>> getPendingPush() async => const [];

  @override
  Future<List<SavedPlaylist>> getTombstones() async => const [];

  @override
  Future<void> upsert(SavedPlaylist playlist) async {}

  @override
  Future<void> hardDelete(String playlistId) async {}

  @override
  Future<void> delete(String playlistId) async {}

  @override
  Future<void> deleteAllUnsaved() async {}

  @override
  Future<String> create({
    required String nome,
    List<PlaylistEntry>? entries,
    List<String> pdfIds = const [],
    List<String> audioIds = const [],
    String? playlistId,
    DateTime? createdAt,
    bool salva = true,
    DateTime? savedAt,
    DateTime? updatedAt,
    int version = 1,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
  }) async => playlistId ?? 'gen';

  @override
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) async {}

  @override
  Future<void> update(
    String playlistId, {
    String? nome,
    List<String>? pdfIds,
    List<String>? audioIds,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
    bool clearFavoritedAt = false,
    DateTime? updatedAt,
    int? version,
    PlaylistSyncStatus? syncStatus,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) async {}
}

/// [SyncPlaylists] roteirizado: [throwsUntilCall] explode nas primeiras
/// chamadas e as seguintes devolvem [result].
class _ScriptedSync extends SyncPlaylists {
  _ScriptedSync({this.result, this.throws, this.throwsUntilCall})
    : super(
        _CountingRepository(),
        (_) async => const <RemotePlaylist>[],
        ({required idToken, required playlist}) async => playlist,
        ({required idToken, required playlistId}) async {},
      );

  final PlaylistSyncResult? result;
  final Object? throws;

  /// Número da última chamada que ainda falha (`1` = só a primeira).
  final int? throwsUntilCall;
  var calls = 0;

  @override
  Future<PlaylistSyncResult> call({required String? idToken}) async {
    calls++;
    final error = throws;
    final limit = throwsUntilCall;
    if (error != null && (limit == null || calls <= limit)) throw error;
    return result ?? const PlaylistSyncResult();
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // `getInstance` é singleton: sem o reload, o cache do teste anterior
    // sobrevive a `setMockInitialValues`.
    await prefs.reload();
  });

  /// Deixa o `unawaited(syncAfterLogin())` do `build()` terminar.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  ProviderContainer buildContainer({
    required PlaylistRepository repository,
    required SyncPlaylists sync,
  }) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(_LoggedInAuth.new),
        playlistRepositoryProvider.overrideWithValue(repository),
        syncPlaylistsProvider.overrideWithValue(sync),
      ],
    );
  }

  test('primeiro login persiste o sub e marca as salvas', () async {
    final repo = _CountingRepository();
    final container = buildContainer(repository: repo, sync: _ScriptedSync());
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();

    expect(repo.markCalls, 1);
    expect(prefs.getString(_subKey), 'sub-1');
  });

  test('reinício com o mesmo sub não repete markAllSavedPendingPush', () async {
    final first = _CountingRepository();
    final container = buildContainer(repository: first, sync: _ScriptedSync());
    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();
    expect(first.markCalls, 1);
    container.dispose();

    // Reinício do app: mesma SharedPreferences, container novo.
    final second = _CountingRepository();
    final secondSync = _ScriptedSync();
    final restarted = buildContainer(repository: second, sync: secondSync);
    addTearDown(restarted.dispose);
    await restarted.read(authStateProvider.future);
    restarted.read(playlistSyncProvider);
    await settle();

    expect(second.markCalls, 0, reason: 'sem transição de conta');
    expect(secondSync.calls, 1, reason: 'boot ainda faz sync simples');
  });

  test('sub diferente volta a marcar tudo como pendingPush', () async {
    await prefs.setString(_subKey, 'outro-sub');
    final repo = _CountingRepository();
    final container = buildContainer(repository: repo, sync: _ScriptedSync());
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();

    expect(repo.markCalls, 1);
    expect(prefs.getString(_subKey), 'sub-1');
  });

  test('markAllSavedPendingPush indisponível vira lastErrorCause', () async {
    final repo = _CountingRepository(
      markThrows: StorageUnavailableException('sem storage'),
    );
    final container = buildContainer(repository: repo, sync: _ScriptedSync());
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();

    expect(
      container.read(playlistSyncProvider).lastErrorCause,
      isA<StorageUnavailableException>(),
    );
    // O sub não é persistido: a próxima abertura tenta de novo.
    expect(prefs.getString(_subKey), isNull);
  });

  test('falha de sync preenche lastErrorCause', () async {
    final failure = StateError('rede caiu');
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: _ScriptedSync(throws: failure),
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await container.read(playlistSyncProvider.notifier).sync();

    expect(container.read(playlistSyncProvider).lastErrorCause, same(failure));
  });

  test('erro do resultado (pull) também vira lastErrorCause', () async {
    final failure = StateError('pull caiu');
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: _ScriptedSync(result: PlaylistSyncResult(pullError: failure)),
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await container.read(playlistSyncProvider.notifier).sync();

    expect(container.read(playlistSyncProvider).lastErrorCause, same(failure));
  });

  test('sync bem-sucedida limpa o erro anterior (mesmo container)', () async {
    // O boot já gasta a chamada 1 (`syncAfterLogin`): a 2 é a que falha e a 3 é
    // o "Tentar novamente" que dá certo — tudo no mesmo notifier.
    final sync = _ScriptedSync(
      throws: StateError('rede caiu'),
      throwsUntilCall: 2,
    );
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: sync,
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();

    final notifier = container.read(playlistSyncProvider.notifier);
    await notifier.sync();
    expect(
      container.read(playlistSyncProvider).lastErrorCause,
      isNotNull,
      reason: 'a sync que falhou deixa o erro no estado',
    );

    await notifier.sync();
    expect(container.read(playlistSyncProvider).lastErrorCause, isNull);
  });

  test('conflitos do resultado chegam ao estado', () async {
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: _ScriptedSync(result: const PlaylistSyncResult(conflicts: 2)),
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    await container.read(playlistSyncProvider.notifier).sync();

    expect(container.read(playlistSyncProvider).conflicts, 2);
  });

  test('cópias de conflito e remoções remotas chegam ao estado', () async {
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: _ScriptedSync(
        result: const PlaylistSyncResult(
          deletedRemotely: 2,
          conflictCopies: ['Culto (cópia local)'],
        ),
      ),
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    await container.read(playlistSyncProvider.notifier).sync();

    final state = container.read(playlistSyncProvider);
    expect(state.deletedRemotely, 2);
    expect(state.conflictCopies, ['Culto (cópia local)']);
    expect(
      state.hasProblem,
      isTrue,
      reason: 'a cópia guardada precisa aparecer no banner',
    );
  });
}
