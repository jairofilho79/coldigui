import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/usecases/ensure_active_playlist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl repository;
  late EnsureActivePlaylist useCase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ensure_active_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    useCase = EnsureActivePlaylist(repository);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('EnsureActivePlaylist cria rascunho com a entrada tipada', () async {
    final result = await useCase(
      entry: PlaylistEntry(id: 'audio-1', kind: MaterialKind.audio),
    );

    expect(result.createdNew, isTrue);
    final created = await repository.getById(result.playlistId);
    expect(created!.salva, isFalse);
    expect(created.entries.single.id, 'audio-1');
    expect(created.entries.single.kind, MaterialKind.audio);
    expect(created.audioIds, ['audio-1']);
  });

  test('reutiliza a lista ativa quando a entrada já está nela', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );

    final result = await useCase(
      entry: PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
      activePlaylistId: 'p1',
    );

    expect(result.playlistId, 'p1');
    expect(result.createdNew, isFalse);
    expect((await repository.getById('p1'))!.entries.length, 1);
  });

  test('acrescenta à lista ativa existente sem criar rascunho', () async {
    await repository.create(
      nome: 'Ativa',
      entries: [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
      playlistId: 'p1',
      salva: false,
    );

    final result = await useCase(
      entry: PlaylistEntry(id: 'b', kind: MaterialKind.pdf),
      activePlaylistId: 'p1',
    );

    expect(result.playlistId, 'p1');
    expect(result.createdNew, isFalse);
    expect((await repository.getById('p1'))!.items, ['a', 'b']);
  });

  test(
    'cria rascunho quando o id ativo aponta para lista inexistente',
    () async {
      final result = await useCase(
        entry: PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
        activePlaylistId: 'sumiu',
      );

      expect(result.createdNew, isTrue);
      expect(result.playlistId, isNot('sumiu'));
    },
  );
}
