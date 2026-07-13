import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

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
}
