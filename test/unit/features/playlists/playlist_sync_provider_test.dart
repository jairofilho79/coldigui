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
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
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

/// Repositório mínimo: conta `adoptForSub`/`purgeSyncedOwnedBy` (e pode falhar
/// na adoção); [surviving] são as listas que `getById` ainda encontra.
class _CountingRepository implements PlaylistRepository {
  _CountingRepository({this.adoptThrows, this.surviving = const {}});

  final Object? adoptThrows;

  /// Ids que `getById` devolve — o resto já sumiu do banco.
  final Set<String> surviving;

  var adoptCalls = 0;
  final purgedSubs = <String>[];
  final adoptedSubs = <String>[];

  @override
  Future<void> adoptForSub(String sub) async {
    adoptCalls++;
    adoptedSubs.add(sub);
    final error = adoptThrows;
    if (error != null) throw error;
  }

  @override
  Future<int> purgeSyncedOwnedBy(String previousSub) async {
    purgedSubs.add(previousSub);
    return 1;
  }

  @override
  Future<List<SavedPlaylist>> getAll() async => const [];

  @override
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab) async => const [];

  @override
  Future<SavedPlaylist?> getById(String playlistId) async {
    if (!surviving.contains(playlistId)) return null;
    return SavedPlaylist.fromLegacyLists(
      playlistId: playlistId,
      nome: playlistId,
      pdfIds: const ['x'],
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<List<SavedPlaylist>> getPendingPush({String? sub}) async => const [];

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
    String? ownerSub,
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
    List<PlaylistEntry>? entries,
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

  /// `sub` recebido em cada chamada, na ordem.
  final subs = <String?>[];

  @override
  Future<PlaylistSyncResult> call({
    required String? idToken,
    required String? sub,
  }) async {
    calls++;
    subs.add(sub);
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

  test('primeiro login persiste o sub e adota as salvas', () async {
    final repo = _CountingRepository();
    final sync = _ScriptedSync();
    final container = buildContainer(repository: repo, sync: sync);
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();

    expect(repo.adoptCalls, 1);
    expect(repo.adoptedSubs, ['sub-1']);
    expect(repo.purgedSubs, isEmpty, reason: 'não havia conta anterior');
    expect(prefs.getString(_subKey), 'sub-1');
    expect(sync.subs, ['sub-1'], reason: 'o use case recebe o dono corrente');
  });

  test('reinício com o mesmo sub não repete adoptForSub', () async {
    final first = _CountingRepository();
    final container = buildContainer(repository: first, sync: _ScriptedSync());
    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();
    expect(first.adoptCalls, 1);
    container.dispose();

    // Reinício do app: mesma SharedPreferences, container novo.
    final second = _CountingRepository();
    final secondSync = _ScriptedSync();
    final restarted = buildContainer(repository: second, sync: secondSync);
    addTearDown(restarted.dispose);
    await restarted.read(authStateProvider.future);
    restarted.read(playlistSyncProvider);
    await settle();

    expect(second.adoptCalls, 0, reason: 'sem transição de conta');
    expect(secondSync.calls, 1, reason: 'boot ainda faz sync simples');
  });

  test('troca de sub purga a conta anterior antes de adotar', () async {
    await prefs.setString(_subKey, 'outro-sub');
    final repo = _CountingRepository();
    final container = buildContainer(repository: repo, sync: _ScriptedSync());
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();

    expect(repo.purgedSubs, ['outro-sub']);
    expect(repo.adoptCalls, 1);
    expect(prefs.getString(_subKey), 'sub-1');
  });

  test('troca de sub limpa o id ativo quando a lista foi purgada', () async {
    await prefs.setString(_subKey, 'outro-sub');
    final repo = _CountingRepository();
    final container = buildContainer(repository: repo, sync: _ScriptedSync());
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(activePlaylistIdProvider.notifier).set('da-conta-antiga');
    container.read(playlistSyncProvider);
    await settle();

    expect(container.read(activePlaylistIdProvider), isNull);
  });

  test('troca de sub preserva o id ativo que sobreviveu à purga', () async {
    await prefs.setString(_subKey, 'outro-sub');
    final repo = _CountingRepository(surviving: const {'pendente'});
    final container = buildContainer(repository: repo, sync: _ScriptedSync());
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(activePlaylistIdProvider.notifier).set('pendente');
    container.read(playlistSyncProvider);
    await settle();

    expect(container.read(activePlaylistIdProvider), 'pendente');
  });

  test('adoptForSub indisponível vira lastErrorCause', () async {
    final repo = _CountingRepository(
      adoptThrows: StorageUnavailableException('sem storage'),
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

  test('exclusão remota limpa o id ativo que sumiu do banco', () async {
    await prefs.setString(_subKey, 'sub-1');
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: _ScriptedSync(result: const PlaylistSyncResult(deletedRemotely: 1)),
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(activePlaylistIdProvider.notifier).set('apagada-fora');
    await container.read(playlistSyncProvider.notifier).sync();

    expect(container.read(activePlaylistIdProvider), isNull);
  });

  test('exclusão remota não mexe no id ativo que continua no banco', () async {
    await prefs.setString(_subKey, 'sub-1');
    final container = buildContainer(
      repository: _CountingRepository(surviving: const {'viva'}),
      sync: _ScriptedSync(result: const PlaylistSyncResult(deletedRemotely: 1)),
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(activePlaylistIdProvider.notifier).set('viva');
    await container.read(playlistSyncProvider.notifier).sync();

    expect(container.read(activePlaylistIdProvider), 'viva');
  });

  test('sync sem exclusão remota não toca no id ativo', () async {
    await prefs.setString(_subKey, 'sub-1');
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: _ScriptedSync(result: const PlaylistSyncResult(pulled: 1)),
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(activePlaylistIdProvider.notifier).set('intocada');
    await container.read(playlistSyncProvider.notifier).sync();

    expect(container.read(activePlaylistIdProvider), 'intocada');
  });
}
