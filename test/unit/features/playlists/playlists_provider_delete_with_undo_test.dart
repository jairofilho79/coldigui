import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/usecases/sync_playlists.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_sync_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';
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
      const AuthUser(googleSub: 'sub-1', idToken: 'token');
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
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
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
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
