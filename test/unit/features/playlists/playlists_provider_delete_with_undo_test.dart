import 'dart:async';
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/sync_playlists.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_sync_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_overrides.dart';

/// Conta as chamadas de sync sem encostar em rede nem em auth.
class _RecordingSyncNotifier extends PlaylistSyncNotifier {
  var calls = 0;

  @override
  PlaylistSyncState build() => const PlaylistSyncState();

  @override
  Future<PlaylistSyncResult> sync() async {
    calls++;
    return PlaylistSyncResult.skippedAuth;
  }
}

/// Usuário autenticado — mesmo padrão de `playlist_sync_provider_test.dart`.
class _LoggedInAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 'sub-1', sessionToken: 'token');
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

/// Decorador de [PlaylistRepository] que permite travar a **próxima**
/// chamada a [getAll] depois que ela já capturou o retorno do repositório
/// real, mas antes de devolvê-lo — reproduz determinística a corrida do fix
/// round 2 (Minor): um `reload()` cuja leitura já começou antes de um
/// `commit()` concorrente, mas que só é observada por quem chamou depois.
class _GatedGetAllRepository implements PlaylistRepository {
  _GatedGetAllRepository(this._inner);

  final PlaylistRepository _inner;
  Completer<void>? _gate;

  /// Arma o travamento; a próxima chamada a [getAll] captura o snapshot do
  /// repositório real na hora, mas só devolve depois que o [Completer]
  /// devolvido for completado.
  Completer<void> armNextGetAll() {
    final gate = Completer<void>();
    _gate = gate;
    return gate;
  }

  @override
  Future<List<SavedPlaylist>> getAll() async {
    final gate = _gate;
    _gate = null;
    final snapshot = await _inner.getAll();
    if (gate != null) await gate.future;
    return snapshot;
  }

  @override
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab) => _inner.getByTab(tab);

  @override
  Future<SavedPlaylist?> getById(String playlistId) =>
      _inner.getById(playlistId);

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
  }) => _inner.create(
    nome: nome,
    entries: entries,
    pdfIds: pdfIds,
    audioIds: audioIds,
    playlistId: playlistId,
    createdAt: createdAt,
    salva: salva,
    savedAt: savedAt,
    updatedAt: updatedAt,
    version: version,
    syncStatus: syncStatus,
    ownerSub: ownerSub,
  );

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
  }) => _inner.update(
    playlistId,
    nome: nome,
    entries: entries,
    pdfIds: pdfIds,
    audioIds: audioIds,
    salva: salva,
    savedAt: savedAt,
    favoritedAt: favoritedAt,
    favorita: favorita,
    clearFavoritedAt: clearFavoritedAt,
    updatedAt: updatedAt,
    version: version,
    syncStatus: syncStatus,
    deletedAt: deletedAt,
    clearDeletedAt: clearDeletedAt,
  );

  @override
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) => _inner.publish(playlistId, category: category, reach: reach);

  @override
  Future<void> delete(String playlistId) => _inner.delete(playlistId);

  @override
  Future<void> hardDelete(String playlistId) => _inner.hardDelete(playlistId);

  @override
  Future<void> deleteAllUnsaved() => _inner.deleteAllUnsaved();

  @override
  Future<List<SavedPlaylist>> getPendingPush({String? sub}) =>
      _inner.getPendingPush(sub: sub);

  @override
  Future<List<SavedPlaylist>> getTombstones({String? sub}) =>
      _inner.getTombstones(sub: sub);

  @override
  Future<void> upsert(SavedPlaylist playlist) => _inner.upsert(playlist);

  @override
  Future<void> adoptForSub(String sub) => _inner.adoptForSub(sub);

  @override
  Future<int> purgeSyncedOwnedBy(String previousSub) =>
      _inner.purgeSyncedOwnedBy(previousSub);
}

/// `PlaylistsNotifier.deleteWithUndo` (C11, spec B.3): exclusão adiada com
/// desfazer — some do estado na hora, comita de verdade só depois da graça
/// (ou de um `commit`/novo `deleteWithUndo`/`dispose` explícitos).
void main() {
  late Directory tempDir;
  late Isar isar;
  late SharedPreferences prefs;
  late PlaylistRepositoryImpl repository;
  late _RecordingSyncNotifier sync;

  Future<ProviderContainer> boot({
    String? activeId,
    bool authed = false,
  }) async {
    SharedPreferences.setMockInitialValues(
      activeId == null ? {} : {kActivePlaylistIdPrefsKey: activeId},
    );
    prefs = await SharedPreferences.getInstance();
    sync = _RecordingSyncNotifier();
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        playlistRepositoryProvider.overrideWithValue(repository),
        playlistSyncProvider.overrideWith(() => sync),
        if (authed) authStateProvider.overrideWith(_LoggedInAuth.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(playlistsProvider);
    await _flush();
    return container;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('delete_with_undo_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('some do estado imediatamente, sem tocar no repositório', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot();

    c.read(playlistsProvider.notifier).deleteWithUndo('p1');

    expect(
      c.read(playlistsProvider).map((i) => i.playlist.playlistId),
      isNot(contains('p1')),
    );
    expect(await repository.getById('p1'), isNotNull);
  });

  // Fix round 1 — Important 1: playlist_sync_provider.dart chama reload()
  // depois de um sync com movedRows; sem filtro, `_reload()` reescreveria o
  // `state` a partir do repositório (que ainda tem a linha — o commit não
  // rodou) e ressuscitaria a lista dentro da janela de graça.
  test(
    'reload() durante a graça não ressuscita a lista com exclusão pendente',
    () async {
      await repository.create(
        nome: 'Rascunho',
        entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
        playlistId: 'p1',
        salva: false,
      );
      final c = await boot();

      final pending = c.read(playlistsProvider.notifier).deleteWithUndo('p1');
      // O repositório ainda tem a linha (commit não rodou) — um reload
      // disparado por sync/manifesto durante a graça não pode trazê-la de
      // volta ao estado.
      expect(await repository.getById('p1'), isNotNull);
      await c.read(playlistsProvider.notifier).reload();

      expect(
        c.read(playlistsProvider).map((i) => i.playlist.playlistId),
        isNot(contains('p1')),
      );

      await pending.undo();
      await c.read(playlistsProvider.notifier).reload();

      expect(
        c.read(playlistsProvider).map((i) => i.playlist.playlistId),
        contains('p1'),
      );
    },
  );

  // Fix round 2 (Minor): `_reload` tem que decidir o `hiddenId` a partir do
  // `_pendingDelete` de ANTES do próprio `await getAll()` — não depois. Um
  // `reload()` cuja leitura já estava em voo quando um `commit()` concorrente
  // assenta (`_settled` vira `true` de forma síncrona, antes do `_onCommit`
  // rodar) não pode devolver a linha só porque o commit "venceu a corrida" da
  // checagem.
  test('reload() cuja leitura começou antes do commit concorrente não '
      'ressuscita a lista', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final gatedRepository = _GatedGetAllRepository(repository);
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        playlistRepositoryProvider.overrideWithValue(gatedRepository),
        playlistSyncProvider.overrideWith(() => sync),
      ],
    );
    addTearDown(container.dispose);
    container.read(playlistsProvider);
    await _flush();

    final pending = container
        .read(playlistsProvider.notifier)
        .deleteWithUndo('p1');

    // Arma o travamento: a leitura do `reload()` abaixo já captura a lista
    // (ainda com "p1", já que o commit não rodou) mas só devolve quando o
    // gate for liberado — simula uma leitura que começou antes do commit.
    final gate = gatedRepository.armNextGetAll();
    final reloadFuture = container.read(playlistsProvider.notifier).reload();
    // Dá tempo do `getAll()` gated capturar o snapshot antes do commit.
    await Future<void>.delayed(Duration.zero);

    // O commit roda e termina por completo (com seu próprio reload interno,
    // que não está mais travado) ANTES da leitura em voo ser liberada.
    await pending.commit();
    gate.complete();
    await reloadFuture;
    await _flush();

    expect(
      container.read(playlistsProvider).map((i) => i.playlist.playlistId),
      isNot(contains('p1')),
    );
  });

  test('undo recoloca a lista e nunca chama o repositório', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot();

    final pending = c.read(playlistsProvider.notifier).deleteWithUndo('p1');
    await pending.undo();
    await _flush();

    expect(
      c.read(playlistsProvider).map((i) => i.playlist.playlistId),
      contains('p1'),
    );
    expect(await repository.getById('p1'), isNotNull);
    expect(pending.isSettled, isTrue);
  });

  test(
    'sem undo, o timer comita depois da graça (hard delete de rascunho)',
    () async {
      await repository.create(
        nome: 'Rascunho',
        entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
        playlistId: 'p1',
        salva: false,
      );
      final c = await boot();

      final pending = c
          .read(playlistsProvider.notifier)
          .deleteWithUndo('p1', grace: Duration.zero);
      await _flush();

      expect(pending.isSettled, isTrue);
      expect(await repository.getById('p1'), isNull);
    },
  );

  test('commit explícito apaga na hora, sem esperar a graça', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot();

    final pending = c.read(playlistsProvider.notifier).deleteWithUndo('p1');
    await pending.commit();

    expect(await repository.getById('p1'), isNull);
  });

  test('um novo deleteWithUndo comita o anterior na hora', () async {
    await repository.create(
      nome: 'Um',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    await repository.create(
      nome: 'Dois',
      entries: [PlaylistEntry(id: 'b', kind: MaterialKind.pdf)],
      playlistId: 'p2',
      salva: false,
    );
    final c = await boot();

    final first = c.read(playlistsProvider.notifier).deleteWithUndo('p1');
    c.read(playlistsProvider.notifier).deleteWithUndo('p2');
    await _flush();

    expect(first.isSettled, isTrue);
    expect(await repository.getById('p1'), isNull, reason: 'p1 já comitou');
    expect(
      await repository.getById('p2'),
      isNotNull,
      reason: 'p2 ainda está na graça',
    );
  });

  test('dispose do notifier comita a pendência ainda em curso', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot();

    c.read(playlistsProvider.notifier).deleteWithUndo('p1');
    c.dispose();
    await _flush();

    expect(await repository.getById('p1'), isNull);
  });

  test(
    'lista salva autenticada: tombstone (soft delete) e sync no commit',
    () async {
      await repository.create(
        nome: 'Salva',
        entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
        playlistId: 'p1',
        salva: true,
      );
      final c = await boot(authed: true);
      await c.read(authStateProvider.future);

      await c
          .read(playlistsProvider.notifier)
          .deleteWithUndo('p1', grace: Duration.zero)
          .commit();
      await _flush();

      final tombstone = await repository.getById('p1');
      expect(tombstone, isNotNull);
      expect(tombstone!.deletedAt, isNotNull);
      expect(sync.calls, 1);
    },
  );

  test('lista salva sem conta: hard delete (sem tombstone órfão)', () async {
    await repository.create(
      nome: 'Salva',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: true,
    );
    final c = await boot();

    await c
        .read(playlistsProvider.notifier)
        .deleteWithUndo('p1', grace: Duration.zero)
        .commit();
    await _flush();

    expect(await repository.getById('p1'), isNull);
    expect(sync.calls, 0);
  });

  test('apagar a lista ativa limpa a seleção ativa no commit', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');
    expect(c.read(activePlaylistIdProvider), 'p1');

    await c
        .read(playlistsProvider.notifier)
        .deleteWithUndo('p1', grace: Duration.zero)
        .commit();
    await _flush();

    expect(c.read(activePlaylistIdProvider), isNull);
  });

  // Fix round 2 (Minor): a seleção ativa não pode continuar apontando pra
  // uma lista que já sumiu do estado — limpa na hora do `deleteWithUndo`
  // (não só no `commit`), e o `undo` restaura.
  test('apagar a lista ativa limpa a seleção na hora (durante a graça) e o '
      'undo restaura', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot(activeId: 'p1');
    expect(c.read(activePlaylistIdProvider), 'p1');

    final pending = c.read(playlistsProvider.notifier).deleteWithUndo('p1');

    expect(
      c.read(activePlaylistIdProvider),
      isNull,
      reason:
          'não pode ficar apontando pra uma lista já removida do estado '
          'durante a graça do desfazer',
    );

    await pending.undo();
    await _flush();

    expect(c.read(activePlaylistIdProvider), 'p1');
  });

  test('delete() continua apagando na hora, sem desfazer', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );
    final c = await boot();

    await c.read(playlistsProvider.notifier).delete('p1');
    await _flush();

    expect(await repository.getById('p1'), isNull);
    expect(
      c.read(playlistsProvider).map((i) => i.playlist.playlistId),
      isNot(contains('p1')),
    );
  });
}
