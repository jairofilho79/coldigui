import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/app_shell/domain/usecases/sync_deep_link_state.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/import_shared_playlist_from_url.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

class _ThrowingPlaylistRepository implements PlaylistRepository {
  _ThrowingPlaylistRepository(this._error);

  final Object _error;

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
  }) {
    throw _error;
  }

  @override
  Future<void> delete(String playlistId) => throw UnimplementedError();

  @override
  Future<void> deleteAllUnsaved() => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getAll() => throw UnimplementedError();

  @override
  Future<SavedPlaylist?> getById(String playlistId) =>
      throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab) =>
      throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getPendingPush({String? sub}) =>
      throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getTombstones() => throw UnimplementedError();

  @override
  Future<void> hardDelete(String playlistId) => throw UnimplementedError();

  @override
  Future<void> adoptForSub(String sub) => throw UnimplementedError();

  @override
  Future<int> purgeSyncedOwnedBy(String previousSub) =>
      throw UnimplementedError();

  @override
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<void> upsert(SavedPlaylist playlist) => throw UnimplementedError();
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late SyncDeepLinkState useCase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_deep_link_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    final playlistRepository = PlaylistRepositoryImpl(
      PlaylistLocalDatasource(isar),
    );
    useCase = SyncDeepLinkState(
      ImportSharedPlaylistFromUrl(playlistRepository),
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('retorna skipped quando URI sem params de share', () async {
    final result = await useCase(uri: Uri.parse('/'));
    expect(result.outcome, SyncDeepLinkOutcome.skipped);
    expect(result.playlistId, isNull);
  });

  test('retorna success e playlistId quando import ok', () async {
    final result = await useCase(
      uri: Uri.parse('/?sharepdfs=a,b&sharename=Ensaio'),
    );
    expect(result.outcome, SyncDeepLinkOutcome.success);
    expect(result.playlistId, isNotEmpty);

    final playlists = isar.playlists.where().findAll();
    expect(playlists.single.nome, 'Ensaio');
  });

  test('aceita queryParams map', () async {
    final result = await useCase(
      queryParams: const {'sharepdfs': 'x', 'sharename': 'Lista'},
    );
    expect(result.outcome, SyncDeepLinkOutcome.success);
    expect(result.playlistId, isNotEmpty);
  });

  test('retorna invalid quando o nome é só espaço', () async {
    final result = await useCase(
      uri: Uri.parse('/?sharepdfs=a&sharename=%20%20'),
    );
    expect(result.outcome, SyncDeepLinkOutcome.invalid);
  });

  test('retorna invalid quando nenhuma lista tem entrada', () async {
    // `sharepdfs= , ` não rende nenhuma entrada, mas o `sharename` está lá:
    // é um share inválido, não "não é share". `parsePlaylistShareParams`
    // devolve params com `entries` vazio e o import lança
    // `InvalidSharePlaylistException` — o usuário vê o aviso (spec D.6).
    final result = await useCase(
      uri: Uri.parse('/?sharepdfs= , &sharename=Nome'),
    );
    expect(result.outcome, SyncDeepLinkOutcome.invalid);
  });

  test('retorna skipped quando a URI não tem sharename', () async {
    final result = await useCase(uri: Uri.parse('/?sharepdfs=a%2Cb'));
    expect(result.outcome, SyncDeepLinkOutcome.skipped);
  });

  test('importa preservando a ordem de shareitems (v2)', () async {
    final result = await useCase(
      uri: Uri.parse(
        '/?shareitems=p%3Apdf-a%2Ca%3Aaud-1%2Cp%3Apdf-b&sharename=Ensaio',
      ),
    );
    expect(result.outcome, SyncDeepLinkOutcome.success);

    final saved = isar.playlists.where().findAll().single;
    expect(saved.items, ['pdf-a', 'aud-1', 'pdf-b']);
    expect(saved.itemKinds, ['pdf', 'audio', 'pdf']);
  });

  test(
    'retorna failed com o StorageUnavailableException quando o repositório lança',
    () async {
      final failing = _ThrowingPlaylistRepository(
        const StorageUnavailableException('playlists.insert'),
      );
      final failingUseCase = SyncDeepLinkState(
        ImportSharedPlaylistFromUrl(failing),
      );

      final result = await failingUseCase(
        uri: Uri.parse('/?sharepdfs=a&sharename=Ensaio'),
      );

      expect(result.outcome, SyncDeepLinkOutcome.failed);
      expect(result.reason, isA<StorageUnavailableException>());
    },
  );

  test(
    'retorna failed sem lançar quando o import falha com exceção genérica',
    () async {
      final failing = _ThrowingPlaylistRepository(StateError('boom'));
      final failingUseCase = SyncDeepLinkState(
        ImportSharedPlaylistFromUrl(failing),
      );

      final result = await failingUseCase(
        uri: Uri.parse('/?sharepdfs=a&sharename=Ensaio'),
      );

      expect(result.outcome, SyncDeepLinkOutcome.failed);
      expect(result.reason, isA<StateError>());
    },
  );
}
