import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

/// Linha pronta para `upsert` — o caminho que grava `syncStatus`/`ownerSub`
/// exatamente como pedido (`create` promove salva+synced a `pendingPush`).
SavedPlaylist _row(
  String id, {
  String? ownerSub,
  PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
  bool salva = true,
}) => SavedPlaylist.fromLegacyLists(
  playlistId: id,
  nome: id,
  pdfIds: const ['x'],
  createdAt: DateTime.utc(2026, 1, 1),
  salva: salva,
  savedAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  syncStatus: syncStatus,
  ownerSub: ownerSub,
);

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playlist_repo_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('create persiste playlist salva por default', () async {
    final id = await repository.create(
      nome: 'Ensaio domingo',
      pdfIds: ['pdf-a', 'pdf-b'],
      playlistId: 'test-id',
      createdAt: DateTime(2026, 6, 8, 10),
    );

    expect(id, 'test-id');
    final saved = await repository.getById('test-id');
    expect(saved?.nome, 'Ensaio domingo');
    expect(saved?.pdfIds, ['pdf-a', 'pdf-b']);
    expect(saved?.salva, isTrue);
    expect(saved?.savedAt, isNotNull);
    expect(saved?.favorita, isFalse);
  });

  test('create não salva com salva false', () async {
    await repository.create(
      nome: 'Rascunho',
      pdfIds: ['a'],
      playlistId: 'draft',
      salva: false,
    );

    final draft = await repository.getById('draft');
    expect(draft?.salva, isFalse);
    expect(draft?.savedAt, isNull);

    final unsaved = await repository.getByTab(PlaylistTab.unsaved);
    expect(unsaved.map((p) => p.playlistId), ['draft']);
  });

  test('getByTab saved ordena por savedAt desc', () async {
    await repository.create(
      nome: 'Antiga',
      pdfIds: ['a'],
      playlistId: 'old',
      createdAt: DateTime(2026, 1, 1),
      savedAt: DateTime(2026, 1, 1),
    );
    await repository.create(
      nome: 'Recente',
      pdfIds: ['b'],
      playlistId: 'new',
      createdAt: DateTime(2026, 6, 1),
      savedAt: DateTime(2026, 6, 8),
    );

    final saved = await repository.getByTab(PlaylistTab.saved);
    expect(saved.map((p) => p.playlistId), ['new', 'old']);
  });

  test('getByTab favorites ordena por favoritedAt desc', () async {
    await repository.create(
      nome: 'F1',
      pdfIds: ['a'],
      playlistId: 'f1',
      savedAt: DateTime(2026, 1, 1),
    );
    await repository.update(
      'f1',
      favorita: true,
      favoritedAt: DateTime(2026, 1, 2),
    );
    await repository.create(
      nome: 'F2',
      pdfIds: ['b'],
      playlistId: 'f2',
      savedAt: DateTime(2026, 6, 1),
    );
    await repository.update(
      'f2',
      favorita: true,
      favoritedAt: DateTime(2026, 6, 8),
    );

    final favorites = await repository.getByTab(PlaylistTab.favorites);
    expect(favorites.map((p) => p.playlistId), ['f2', 'f1']);
  });

  test('update nome e pdfIds', () async {
    await repository.create(
      nome: 'Original',
      pdfIds: ['a', 'b'],
      playlistId: 'p1',
    );

    await repository.update('p1', nome: 'Renomeada', pdfIds: ['a', 'c']);

    final saved = await repository.getById('p1');
    expect(saved?.nome, 'Renomeada');
    expect(saved?.pdfIds, ['a', 'c']);
  });

  test('deleteAllUnsaved remove apenas rascunhos', () async {
    await repository.create(
      nome: 'Rascunho',
      pdfIds: ['a'],
      playlistId: 'draft',
      salva: false,
    );
    await repository.create(
      nome: 'Salva',
      pdfIds: ['b'],
      playlistId: 'saved',
      salva: true,
    );

    await repository.deleteAllUnsaved();

    expect(await repository.getById('draft'), isNull);
    expect(await repository.getById('saved'), isNotNull);
  });

  test('delete soft-delete lista salva e some de getAll', () async {
    await repository.create(nome: 'Lista', pdfIds: ['a'], playlistId: 'p1');

    await repository.delete('p1');
    final tomb = await repository.getById('p1');
    expect(tomb?.deletedAt, isNotNull);
    expect(await repository.getAll(), isEmpty);

    await repository.delete('missing');
    expect(await repository.getAll(), isEmpty);
  });

  test('delete hard-remove rascunho', () async {
    await repository.create(
      nome: 'Draft',
      pdfIds: ['a'],
      playlistId: 'd1',
      salva: false,
    );

    await repository.delete('d1');
    expect(await repository.getById('d1'), isNull);
  });

  group('dono por conta (A.5)', () {
    test('create grava o ownerSub informado', () async {
      await repository.create(
        nome: 'Minha',
        pdfIds: ['a'],
        playlistId: 'p1',
        ownerSub: 'sub-1',
      );

      expect((await repository.getById('p1'))?.ownerSub, 'sub-1');
    });

    test('adoptForSub marca só as salvas sem dono ou do mesmo dono', () async {
      await repository.upsert(_row('orfa'));
      await repository.upsert(_row('minha', ownerSub: 'sub-1'));
      await repository.upsert(_row('outra', ownerSub: 'sub-2'));
      await repository.upsert(_row('draft', salva: false));

      await repository.adoptForSub('sub-1');

      final orfa = await repository.getById('orfa');
      expect(orfa?.ownerSub, 'sub-1');
      expect(orfa?.syncStatus, PlaylistSyncStatus.pendingPush);

      final minha = await repository.getById('minha');
      expect(minha?.ownerSub, 'sub-1');
      expect(minha?.syncStatus, PlaylistSyncStatus.pendingPush);

      final outra = await repository.getById('outra');
      expect(outra?.ownerSub, 'sub-2', reason: 'lista de outra conta não muda');
      expect(outra?.syncStatus, PlaylistSyncStatus.synced);

      final draft = await repository.getById('draft');
      expect(draft?.ownerSub, isNull, reason: 'rascunho nunca ganha dono');
      expect(draft?.syncStatus, PlaylistSyncStatus.synced);
    });

    test(
      'purgeSyncedOwnedBy apaga synced da conta anterior e mantém pendingPush',
      () async {
        await repository.upsert(_row('sincronizada', ownerSub: 'antigo'));
        await repository.upsert(
          _row(
            'pendente',
            ownerSub: 'antigo',
            syncStatus: PlaylistSyncStatus.pendingPush,
          ),
        );
        await repository.upsert(
          _row(
            'conflito',
            ownerSub: 'antigo',
            syncStatus: PlaylistSyncStatus.conflict,
          ),
        );
        await repository.upsert(_row('nova-conta', ownerSub: 'novo'));
        await repository.upsert(_row('sem-dono'));

        final purged = await repository.purgeSyncedOwnedBy('antigo');

        expect(purged, 1);
        expect(await repository.getById('sincronizada'), isNull);
        expect(await repository.getById('pendente'), isNotNull);
        expect(await repository.getById('conflito'), isNotNull);
        expect(await repository.getById('nova-conta'), isNotNull);
        expect(await repository.getById('sem-dono'), isNotNull);
      },
    );

    test('getPendingPush só entrega o dono corrente e as sem dono', () async {
      await repository.upsert(
        _row('sem-dono', syncStatus: PlaylistSyncStatus.pendingPush),
      );
      await repository.upsert(
        _row(
          'minha',
          ownerSub: 'sub-1',
          syncStatus: PlaylistSyncStatus.pendingPush,
        ),
      );
      await repository.upsert(
        _row(
          'outra',
          ownerSub: 'sub-2',
          syncStatus: PlaylistSyncStatus.pendingPush,
        ),
      );

      final pending = await repository.getPendingPush(sub: 'sub-1');

      expect(pending.map((p) => p.playlistId).toSet(), {'sem-dono', 'minha'});
    });
  });
}
