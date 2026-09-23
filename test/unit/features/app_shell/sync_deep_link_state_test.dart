import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/app_shell/domain/usecases/sync_deep_link_state.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/ports/praise_entry_resolver.dart';
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
  Future<List<SavedPlaylist>> getAll() async => const <SavedPlaylist>[];

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
  Future<List<SavedPlaylist>> getTombstones({String? sub}) =>
      throw UnimplementedError();

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

const _pdfA = PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf);
const _audio1 = PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio);

PraiseEntryResolverLoader _catalog(Map<String, PlaylistEntry> entries) =>
    () async =>
        (shortId) => entries[shortId];

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl playlistRepository;
  late SyncDeepLinkState useCase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_deep_link_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    playlistRepository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    useCase = SyncDeepLinkState(
      ImportSharedPlaylistFromUrl(
        playlistRepository,
        loadPraiseEntryResolver: _catalog({'0a1': _pdfA, '0c3': _audio1}),
      ),
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('skipped quando a URI não tem link de lista', () async {
    expect(
      (await useCase(uri: Uri.parse('/'))).outcome,
      SyncDeepLinkOutcome.skipped,
    );
    expect(
      (await useCase(uri: Uri.parse('/?n=Culto'))).outcome,
      SyncDeepLinkOutcome.skipped,
    );
  });

  test('success com ?p=&n=, na ordem e com repetição', () async {
    final result = await useCase(
      uri: Uri.parse('https://v2.plpcg.com/?p=0a1-0c3-0a1&n=Culto'),
    );
    expect(result.outcome, SyncDeepLinkOutcome.success);
    expect(result.playlistId, isNotEmpty);
    expect(result.skippedCount, 0);

    final saved = isar.playlists.where().findAll().single;
    expect(saved.nome, 'Culto');
    expect(saved.items, ['pdf-a', 'aud-1', 'pdf-a']);
    expect(saved.itemKinds, ['pdf', 'audio', 'pdf']);
  });

  test('success leva a contagem de louvores que ficaram de fora', () async {
    final result = await useCase(uri: Uri.parse('/?p=0a1-abc-0c3-fff&n=Culto'));
    expect(result.outcome, SyncDeepLinkOutcome.success);
    expect(result.skippedCount, 2);
  });

  test('aceita queryParams map', () async {
    final result = await useCase(queryParams: const {'p': '0a1', 'n': 'Lista'});
    expect(result.outcome, SyncDeepLinkOutcome.success);
  });

  test('invalid quando o nome é só espaço', () async {
    final result = await useCase(uri: Uri.parse('/?p=0a1&n=%20%20'));
    expect(result.outcome, SyncDeepLinkOutcome.invalid);
  });

  test('invalid quando p não tem token válido', () async {
    final result = await useCase(uri: Uri.parse('/?p=zz&n=Nome'));
    expect(result.outcome, SyncDeepLinkOutcome.invalid);
  });

  test('invalid quando nenhum token é conhecido', () async {
    final result = await useCase(uri: Uri.parse('/?p=abc&n=Nome'));
    expect(result.outcome, SyncDeepLinkOutcome.invalid);
  });

  test('legacy para cada formato antigo, sem gravar nada', () async {
    for (final uri in [
      '/?s=1a2f-0000&n=Culto',
      '/?sharepdfs=a&sharename=Ensaio',
      '/?shareitems=p%3Aa&sharename=Ensaio',
      'plpcg:///?s=1a2f&n=Culto',
    ]) {
      final result = await useCase(uri: Uri.parse(uri));
      expect(result.outcome, SyncDeepLinkOutcome.legacy, reason: uri);
    }
    expect(isar.playlists.where().findAll(), isEmpty);
  });

  test(
    'failed com o StorageUnavailableException quando o repositório lança',
    () async {
      final failingUseCase = SyncDeepLinkState(
        ImportSharedPlaylistFromUrl(
          _ThrowingPlaylistRepository(
            const StorageUnavailableException('playlists.insert'),
          ),
          loadPraiseEntryResolver: _catalog({'0a1': _pdfA}),
        ),
      );
      final result = await failingUseCase(uri: Uri.parse('/?p=0a1&n=Ensaio'));
      expect(result.outcome, SyncDeepLinkOutcome.failed);
      expect(result.reason, isA<StorageUnavailableException>());
    },
  );

  test(
    'alreadyExisted e o nome da lista existente quando o import dedupa',
    () async {
      final first = await useCase(uri: Uri.parse('/?p=0a1-0c3&n=Original'));
      expect(first.alreadyExisted, isFalse);

      final second = await useCase(
        uri: Uri.parse('/?p=0a1-0c3&n=Outro%20nome'),
      );

      expect(second.outcome, SyncDeepLinkOutcome.success);
      expect(second.alreadyExisted, isTrue);
      expect(second.playlistId, first.playlistId);
      expect(second.nome, 'Original');
      expect(isar.playlists.where().findAll(), hasLength(1));
    },
  );

  test(
    'failed sem lançar quando o import falha com exceção genérica',
    () async {
      final failingUseCase = SyncDeepLinkState(
        ImportSharedPlaylistFromUrl(
          _ThrowingPlaylistRepository(StateError('boom')),
          loadPraiseEntryResolver: _catalog({'0a1': _pdfA}),
        ),
      );
      final result = await failingUseCase(uri: Uri.parse('/?p=0a1&n=Ensaio'));
      expect(result.outcome, SyncDeepLinkOutcome.failed);
      expect(result.reason, isA<StateError>());
    },
  );
}
