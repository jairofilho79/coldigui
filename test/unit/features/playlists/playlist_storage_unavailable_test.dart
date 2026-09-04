// test/unit/features/playlists/playlist_storage_unavailable_test.dart
//
// Isar indisponível (modo degradado, B5): leituras devolvem vazio/`null`;
// escritas **não podem fingir sucesso**.
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:flutter_test/flutter_test.dart';

final pdfA = encodePdfId('ColAdultos/001.pdf');
final audioA = encodePdfId('assets/praises/a/001.mp3');

Matcher _throwsStorageUnavailable(String operation) => throwsA(
  isA<StorageUnavailableException>().having(
    (e) => e.operation,
    'operation',
    operation,
  ),
);

void main() {
  const datasource = PlaylistLocalDatasource.unavailable();
  const repository = PlaylistRepositoryImpl(datasource);

  group('PlaylistLocalDatasource sem Isar — escritas lançam', () {
    test('insert', () {
      expect(
        () => datasource.insert(Playlist()..playlistId = 'p1'),
        _throwsStorageUnavailable('playlists.insert'),
      );
    });

    test('updateFields', () {
      expect(
        () => datasource.updateFields('p1', nome: 'Outro'),
        _throwsStorageUnavailable('playlists.update'),
      );
    });

    test('softDeleteByPlaylistId', () {
      expect(
        () => datasource.softDeleteByPlaylistId('p1'),
        _throwsStorageUnavailable('playlists.softDelete'),
      );
    });

    test('deleteByPlaylistId', () {
      expect(
        () => datasource.deleteByPlaylistId('p1'),
        _throwsStorageUnavailable('playlists.delete'),
      );
    });

    test('deleteAllUnsaved', () {
      expect(
        () => datasource.deleteAllUnsaved(),
        _throwsStorageUnavailable('playlists.deleteAllUnsaved'),
      );
    });

    test('markAllSavedPendingPush', () {
      expect(
        () => datasource.markAllSavedPendingPush(),
        _throwsStorageUnavailable('playlists.markAllSavedPendingPush'),
      );
    });
  });

  group('PlaylistLocalDatasource sem Isar — leituras seguem vazias', () {
    test('findAll e amigos devolvem lista vazia', () async {
      expect(await datasource.findAll(), isEmpty);
      expect(await datasource.findUnsaved(), isEmpty);
      expect(await datasource.findSaved(), isEmpty);
      expect(await datasource.findFavorites(), isEmpty);
      expect(await datasource.findPendingPush(), isEmpty);
      expect(await datasource.findTombstones(), isEmpty);
      expect(await datasource.findAllSavedIncludingDeleted(), isEmpty);
    });

    test('findByPlaylistId devolve null', () async {
      expect(await datasource.findByPlaylistId('p1'), isNull);
    });
  });

  group('PlaylistRepositoryImpl sem Isar', () {
    test('create propaga em vez de devolver um id não persistido', () {
      expect(
        () => repository.create(nome: 'Nova', pdfIds: [pdfA]),
        _throwsStorageUnavailable('playlists.insert'),
      );
    });

    test('upsert propaga', () {
      expect(
        () => repository.upsert(
          SavedPlaylist(
            playlistId: 'p1',
            nome: 'Ensaio',
            entries: [PlaylistEntry.audio(audioA)],
            createdAt: DateTime.utc(2026, 9, 1),
          ),
        ),
        _throwsStorageUnavailable('playlists.insert'),
      );
    });

    test('hardDelete propaga', () {
      expect(
        () => repository.hardDelete('p1'),
        _throwsStorageUnavailable('playlists.delete'),
      );
    });

    test('markAllSavedPendingPush propaga', () {
      expect(
        () => repository.markAllSavedPendingPush(),
        _throwsStorageUnavailable('playlists.markAllSavedPendingPush'),
      );
    });

    test('leituras continuam devolvendo vazio/null', () async {
      expect(await repository.getAll(), isEmpty);
      expect(await repository.getById('p1'), isNull);
      expect(await repository.getPendingPush(), isEmpty);
      expect(await repository.getTombstones(), isEmpty);
    });

    test('delete de playlist inexistente continua no-op', () async {
      // `delete` lê antes de escrever: sem linha, não há escrita a fazer.
      await expectLater(repository.delete('p1'), completes);
    });
  });
}
