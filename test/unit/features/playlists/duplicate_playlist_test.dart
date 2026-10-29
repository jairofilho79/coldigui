import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/usecases/duplicate_playlist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

/// `DuplicatePlaylist` (C11, spec B.3): cópia salva com as mesmas entradas,
/// nome já formatado pelo chamador e sem herdar publicação/sync da original.
void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl repository;
  late DuplicatePlaylist useCase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('duplicate_playlist_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    useCase = DuplicatePlaylist(repository);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('cria cópia salva com id novo, mesmas entradas e nome pedido', () async {
    await repository.create(
      nome: 'Ensaio domingo',
      entries: [
        PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
        PlaylistEntry(id: 'b', kind: MaterialKind.audio),
        PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
      ],
      playlistId: 'p1',
      salva: true,
    );

    final copy = await useCase(
      playlistId: 'p1',
      copyName: 'Ensaio domingo (cópia)',
    );

    expect(copy.playlistId, isNot('p1'));
    expect(copy.nome, 'Ensaio domingo (cópia)');
    expect(copy.salva, isTrue);
    expect(copy.entries.map((e) => (e.id, e.kind)), [
      ('a', MaterialKind.pdf),
      ('b', MaterialKind.audio),
      ('a', MaterialKind.pdf),
    ]);
    expect(copy.syncStatus, PlaylistSyncStatus.pendingPush);
    expect(copy.isPublished, isFalse);

    // A original continua intacta.
    final original = await repository.getById('p1');
    expect(original!.entries.length, 3);
  });

  test('duplica rascunho como lista salva', () async {
    await repository.create(
      nome: 'Rascunho',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'd1',
      salva: false,
    );

    final copy = await useCase(playlistId: 'd1', copyName: 'Rascunho (cópia)');

    expect(copy.salva, isTrue);
  });

  test('não herda publicação da original', () async {
    await repository.create(
      nome: 'Publicada',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p2',
      salva: true,
    );
    await repository.publish('p2', category: PlaylistCategory.evangelizacao);

    final copy = await useCase(playlistId: 'p2', copyName: 'Publicada (cópia)');

    expect(copy.isPublished, isFalse);
    expect(copy.publicationCategory, isNull);
    expect(copy.publishedAt, isNull);
  });

  test('lança StateError quando a playlist não existe', () {
    expect(
      () => useCase(playlistId: 'ausente', copyName: 'x'),
      throwsStateError,
    );
  });
}
