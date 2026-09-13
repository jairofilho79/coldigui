import 'dart:async';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/network/connectivity_stream_provider.dart';
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
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
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

  /// Diário **ordenado** das chamadas de dono (`purge:<sub>` / `adopt:<sub>`).
  ///
  /// Ordenado de propósito: contadores separados não distinguem
  /// purga-antes-de-adoção de adoção-antes-de-purga, e é justamente essa ordem
  /// que impede as listas da conta anterior de subirem para a conta nova.
  final calls = <String>[];

  int get adoptCalls => calls.where((c) => c.startsWith('adopt:')).length;

  @override
  Future<void> adoptForSub(String sub) async {
    calls.add('adopt:$sub');
    final error = adoptThrows;
    if (error != null) throw error;
  }

  @override
  Future<int> purgeSyncedOwnedBy(String previousSub) async {
    calls.add('purge:$previousSub');
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
  Future<List<SavedPlaylist>> getTombstones({String? sub}) async => const [];

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

/// Conta os `reload()` da tela sem tocar em Isar nem no manifest.
class _CountingPlaylists extends PlaylistsNotifier {
  var reloadCalls = 0;

  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<void> reload() async => reloadCalls++;
}

/// [SyncPlaylists] roteirizado: [throwsUntilCall] explode nas primeiras
/// chamadas e as seguintes devolvem [result].
class _ScriptedSync extends SyncPlaylists {
  _ScriptedSync({this.result, this.throws, this.throwsUntilCall, this.gate})
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

  /// Segura a rodada até o teste liberar — para descartar o container com uma
  /// sync em voo.
  final Completer<void>? gate;

  /// `sub` recebido em cada chamada, na ordem.
  final subs = <String?>[];

  @override
  Future<PlaylistSyncResult> call({
    required String? idToken,
    required String? sub,
  }) async {
    calls++;
    subs.add(sub);
    await gate?.future;
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
    PlaylistSyncNotifier.reconnectDebounce = const Duration(milliseconds: 5);
  });

  tearDown(() {
    PlaylistSyncNotifier.reconnectDebounce = const Duration(seconds: 2);
  });

  /// Deixa o `unawaited(syncAfterLogin())` do `build()` terminar.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  ProviderContainer buildContainer({
    required PlaylistRepository repository,
    required SyncPlaylists sync,
    Stream<bool>? connectivity,
    Future<Isar>? isarReady,
    PlaylistsNotifier Function()? playlists,
  }) {
    return ProviderContainer(
      overrides: [
        // O boot espera o Isar assentar. Sem `isarReady`, ele já nasce
        // degradado: nenhum teste daqui usa a instância de verdade (o
        // repositório é fake), e abrir o Isar real seria só lentidão.
        isarInitializerProvider.overrideWith(
          (ref) =>
              isarReady ??
              Future<Isar>.error(StateError('Isar não é usado neste teste')),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(_LoggedInAuth.new),
        playlistRepositoryProvider.overrideWithValue(repository),
        syncPlaylistsProvider.overrideWithValue(sync),
        if (connectivity != null)
          connectivityStreamProvider.overrideWith((ref) => connectivity),
        if (playlists != null) playlistsProvider.overrideWith(playlists),
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

    expect(
      repo.calls,
      ['adopt:sub-1'],
      reason: 'primeiro login adota, sem purgar — não havia conta anterior',
    );
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

    expect(
      repo.calls,
      ['purge:outro-sub', 'adopt:sub-1'],
      reason:
          'purgar depois de adotar levaria as listas da conta anterior '
          'para a conta nova',
    );
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

  test(
    'retryAndReload refaz o pós-login quando o sub não foi persistido',
    () async {
      final repo = _CountingRepository(adoptThrows: StateError('storage fora'));
      final container = buildContainer(repository: repo, sync: _ScriptedSync());
      addTearDown(container.dispose);

      await container.read(authStateProvider.future);
      container.read(playlistSyncProvider);
      await settle();
      expect(repo.adoptCalls, 1);
      expect(prefs.getString(_subKey), isNull);

      await container.read(playlistSyncProvider.notifier).retryAndReload();

      expect(repo.adoptCalls, 2, reason: 'a adoção pendente é refeita');
    },
  );

  test('retryAndReload não recarrega a tela com adoção falhando', () async {
    final repo = _CountingRepository(adoptThrows: StateError('storage fora'));
    final screen = _CountingPlaylists();
    final container = buildContainer(
      repository: repo,
      sync: _ScriptedSync(result: const PlaylistSyncResult(pulled: 1)),
      playlists: () => screen,
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();
    expect(repo.adoptCalls, 1, reason: 'o boot já tentou adotar e falhou');

    // Uma sync que deu certo deixa `lastResult` preenchido…
    await container.read(playlistSyncProvider.notifier).sync();
    expect(container.read(playlistSyncProvider).lastResult?.pulled, 1);
    final before = screen.reloadCalls;

    // …e o retry seguinte volta a falhar na adoção, sem chegar a sincronizar.
    // Recarregar a tela com o `lastResult` velho mostraria movimento que não
    // houve.
    await container.read(playlistSyncProvider.notifier).retryAndReload();

    expect(repo.adoptCalls, 2);
    expect(screen.reloadCalls, before);
  });

  test('retryAndReload recarrega quando a adoção e a sync dão certo', () async {
    final screen = _CountingPlaylists();
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: _ScriptedSync(result: const PlaylistSyncResult(pulled: 1)),
      playlists: () => screen,
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();
    // O boot já adotou e persistiu o sub; força o caminho pós-login de novo.
    await prefs.remove(_subKey);
    final before = screen.reloadCalls;

    await container.read(playlistSyncProvider.notifier).retryAndReload();

    expect(screen.reloadCalls, before + 1);
  });

  test('retryAndReload só sincroniza com o sub já persistido', () async {
    await prefs.setString(_subKey, 'sub-1');
    final repo = _CountingRepository();
    final sync = _ScriptedSync();
    final container = buildContainer(repository: repo, sync: sync);
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();
    final before = sync.calls;

    await container.read(playlistSyncProvider.notifier).retryAndReload();

    expect(repo.adoptCalls, 0);
    expect(sync.calls, before + 1);
  });

  group('reload da tela após a sync (#1)', () {
    test('sync do boot que trouxe linhas recarrega a tela', () async {
      // Sub já persistido: o boot faz `sync()` puro, sem adoção — o caminho
      // que nunca recarregava e deixava o carousel espelhando a lista velha.
      await prefs.setString(_subKey, 'sub-1');
      final screen = _CountingPlaylists();
      final container = buildContainer(
        repository: _CountingRepository(),
        sync: _ScriptedSync(result: const PlaylistSyncResult(pulled: 1)),
        playlists: () => screen,
      );
      addTearDown(container.dispose);

      await container.read(authStateProvider.future);
      container.read(playlistSyncProvider);
      await settle();

      expect(screen.reloadCalls, 1);
    });

    test('push sozinho também recarrega (version/syncStatus mudam)', () async {
      await prefs.setString(_subKey, 'sub-1');
      final screen = _CountingPlaylists();
      final container = buildContainer(
        repository: _CountingRepository(),
        sync: _ScriptedSync(result: const PlaylistSyncResult(pushed: 1)),
        playlists: () => screen,
      );
      addTearDown(container.dispose);

      await container.read(authStateProvider.future);
      container.read(playlistSyncProvider);
      await settle();

      expect(screen.reloadCalls, 1);
    });

    test('sync que não moveu nada não recarrega', () async {
      await prefs.setString(_subKey, 'sub-1');
      final screen = _CountingPlaylists();
      final container = buildContainer(
        repository: _CountingRepository(),
        sync: _ScriptedSync(),
        playlists: () => screen,
      );
      addTearDown(container.dispose);

      await container.read(authStateProvider.future);
      container.read(playlistSyncProvider);
      await settle();
      await container.read(playlistSyncProvider.notifier).sync();

      expect(screen.reloadCalls, 0);
    });

    test(
      'troca de sub recarrega depois da purga mesmo sem a sync mover',
      () async {
        // `_CountingRepository.purgeSyncedOwnedBy` devolve 1: as listas da conta
        // anterior sumiram do banco e a tela não pode continuar mostrando-as.
        await prefs.setString(_subKey, 'outro-sub');
        final screen = _CountingPlaylists();
        final container = buildContainer(
          repository: _CountingRepository(),
          sync: _ScriptedSync(),
          playlists: () => screen,
        );
        addTearDown(container.dispose);

        await container.read(authStateProvider.future);
        container.read(playlistSyncProvider);
        await settle();

        expect(screen.reloadCalls, 1);
      },
    );

    test(
      'volta da conectividade recarrega quando a sync trouxe linhas',
      () async {
        await prefs.setString(_subKey, 'sub-1');
        final screen = _CountingPlaylists();
        final connectivity = StreamController<bool>.broadcast();
        addTearDown(connectivity.close);
        final container = buildContainer(
          repository: _CountingRepository(),
          sync: _ScriptedSync(result: const PlaylistSyncResult(pulled: 1)),
          connectivity: connectivity.stream,
          playlists: () => screen,
        );
        addTearDown(container.dispose);

        await container.read(authStateProvider.future);
        container.listen(playlistSyncProvider, (_, _) {});
        await settle();
        final before = screen.reloadCalls;

        connectivity.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        connectivity.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(screen.reloadCalls, before + 1);
      },
    );
  });

  test('descartar o container no meio da sync não estoura', () async {
    await prefs.setString(_subKey, 'sub-1');
    final gate = Completer<void>();
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: _ScriptedSync(gate: gate),
    );

    await container.read(authStateProvider.future);
    final pending = container.read(playlistSyncProvider.notifier).sync();
    container.dispose();
    gate.complete();

    // `state` é `ref`: sem guarda de `mounted` depois do `await`, ler o
    // resultado num notifier já descartado estouraria num callback sem dono.
    await expectLater(pending, completion(isA<PlaylistSyncResult>()));
  });

  test('boot espera o Isar assentar antes de tocar no repositório', () async {
    final repo = _CountingRepository();
    final sync = _ScriptedSync();
    final isarReady = Completer<Isar>();
    final container = buildContainer(
      repository: repo,
      sync: sync,
      isarReady: isarReady.future,
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistSyncProvider);
    await settle();

    expect(repo.adoptCalls, 0, reason: 'o Isar ainda está abrindo');
    expect(sync.calls, 0, reason: 'nada sobe antes do banco estar de pé');
    expect(prefs.getString(_subKey), isNull);

    // Modo degradado: a abertura falhou. O pós-login segue mesmo assim — quem
    // reclama é o repositório, com StorageUnavailableException.
    isarReady.completeError(StateError('OPFS travou'));
    await settle();

    expect(repo.adoptCalls, 1);
    expect(sync.calls, 1);
  });

  test('volta da conectividade dispara sync depois do debounce', () async {
    await prefs.setString(_subKey, 'sub-1');
    final sync = _ScriptedSync();
    final connectivity = StreamController<bool>.broadcast();
    addTearDown(connectivity.close);
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: sync,
      connectivity: connectivity.stream,
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    // `listen`, e não `read`: no Riverpod 3 um provider sem ouvinte ativo tem
    // as próprias assinaturas pausadas — o `ref.listen` da conectividade só
    // recebe eventos enquanto alguém observa o notifier (na tela, a lista).
    container.listen(playlistSyncProvider, (_, _) {});
    await settle();
    final before = sync.calls;

    connectivity.add(false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sync.calls, before, reason: 'ficar offline não sincroniza');

    connectivity.add(true);
    expect(sync.calls, before, reason: 'o debounce ainda não venceu');
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(sync.calls, before + 1);
  });
}
