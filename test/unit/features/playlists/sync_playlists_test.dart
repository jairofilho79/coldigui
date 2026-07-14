import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/remote_playlist.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/sync_playlists.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPlaylistRepository implements PlaylistRepository {
  final map = <String, SavedPlaylist>{};

  @override
  Future<String> create({
    required String nome,
    required List<String> pdfIds,
    List<String> audioIds = const [],
    String? playlistId,
    DateTime? createdAt,
    bool salva = true,
    DateTime? savedAt,
    DateTime? updatedAt,
    int version = 1,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
  }) async {
    final id = playlistId ?? 'gen';
    final now = createdAt ?? DateTime.utc(2026, 1, 1);
    map[id] = SavedPlaylist(
      playlistId: id,
      nome: nome,
      pdfIds: pdfIds,
      audioIds: audioIds,
      createdAt: now,
      salva: salva,
      savedAt: savedAt ?? (salva ? now : null),
      updatedAt: updatedAt ?? now,
      version: version,
      syncStatus: salva ? PlaylistSyncStatus.pendingPush : syncStatus,
    );
    return id;
  }

  @override
  Future<void> delete(String playlistId) async {
    final existing = map[playlistId];
    if (existing == null) return;
    if (existing.salva) {
      map[playlistId] = existing.copyWith(
        deletedAt: DateTime.utc(2026, 6, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
        updatedAt: DateTime.utc(2026, 6, 1),
      );
    } else {
      map.remove(playlistId);
    }
  }

  @override
  Future<void> deleteAllUnsaved() async {
    map.removeWhere((_, p) => !p.salva);
  }

  @override
  Future<List<SavedPlaylist>> getAll() async =>
      map.values.where((p) => p.deletedAt == null).toList();

  @override
  Future<SavedPlaylist?> getById(String playlistId) async => map[playlistId];

  @override
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab) async => getAll();

  @override
  Future<List<SavedPlaylist>> getPendingPush() async => map.values
      .where(
        (p) =>
            p.salva &&
            p.deletedAt == null &&
            p.syncStatus == PlaylistSyncStatus.pendingPush,
      )
      .toList();

  @override
  Future<List<SavedPlaylist>> getTombstones() async => map.values
      .where(
        (p) =>
            p.deletedAt != null &&
            p.syncStatus == PlaylistSyncStatus.pendingPush,
      )
      .toList();

  @override
  Future<void> hardDelete(String playlistId) async {
    map.remove(playlistId);
  }

  @override
  Future<void> markAllSavedPendingPush() async {
    for (final e in map.entries.toList()) {
      if (e.value.salva && e.value.deletedAt == null) {
        map[e.key] = e.value.copyWith(
          syncStatus: PlaylistSyncStatus.pendingPush,
        );
      }
    }
  }

  @override
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) async {
    final existing = map[playlistId];
    if (existing == null) throw StateError('missing');
    if (!existing.salva || existing.isPublished) {
      throw StateError('cannot publish');
    }
    final now = DateTime.utc(2026, 7, 13);
    map[playlistId] = existing.copyWith(
      isPublished: true,
      publicationCategory: category,
      publicationReach: reach,
      publishedAt: now,
      updatedAt: now,
      syncStatus: PlaylistSyncStatus.pendingPush,
    );
  }

  @override
  Future<void> update(
    String playlistId, {
    String? nome,
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
  }) async {
    final existing = map[playlistId];
    if (existing == null) throw StateError('missing');
    map[playlistId] = existing.copyWith(
      nome: nome,
      pdfIds: pdfIds,
      audioIds: audioIds,
      salva: salva,
      savedAt: savedAt,
      favoritedAt: clearFavoritedAt ? null : favoritedAt,
      favorita: favorita,
      updatedAt: updatedAt,
      version: version,
      syncStatus: syncStatus,
      deletedAt: deletedAt,
      clearDeletedAt: clearDeletedAt,
    );
  }

  @override
  Future<void> upsert(SavedPlaylist playlist) async {
    map[playlist.playlistId] = playlist;
  }
}

void main() {
  test('sem idToken não chama rede', () async {
    var fetchCalled = false;
    final sync = SyncPlaylists(
      _MemoryPlaylistRepository(),
      (_) async {
        fetchCalled = true;
        return <RemotePlaylist>[];
      },
      ({required idToken, required playlist}) async => playlist,
      ({required idToken, required playlistId}) async {},
    );

    final result = await sync(idToken: null);
    expect(result.skipped, isTrue);
    expect(fetchCalled, isFalse);
  });

  test('pull insere remota ausente localmente', () async {
    final repo = _MemoryPlaylistRepository();
    final remote = RemotePlaylist(
      id: 'r1',
      nome: 'Culto',
      pdfIds: const ['a'],
      salva: true,
      favorita: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 2, 1),
      version: 2,
      savedAt: DateTime.utc(2026, 1, 1),
    );

    final sync = SyncPlaylists(
      repo,
      (_) async => [remote],
      ({required idToken, required playlist}) async => playlist,
      ({required idToken, required playlistId}) async {},
    );

    final result = await sync(idToken: 'token');
    expect(result.pulled, 1);
    expect(repo.map['r1']?.nome, 'Culto');
    expect(repo.map['r1']?.syncStatus, PlaylistSyncStatus.synced);
  });

  test('pendingPush local mais novo não é sobrescrito no pull', () async {
    final repo = _MemoryPlaylistRepository();
    await repo.upsert(
      SavedPlaylist(
        playlistId: 'p1',
        nome: 'Local',
        pdfIds: const ['x'],
        createdAt: DateTime.utc(2026, 1, 1),
        salva: true,
        updatedAt: DateTime.utc(2026, 3, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
      ),
    );

    final sync = SyncPlaylists(
      repo,
      (_) async => [
        RemotePlaylist(
          id: 'p1',
          nome: 'Remoto',
          pdfIds: const ['y'],
          salva: true,
          favorita: false,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 2, 1),
          version: 5,
        ),
      ],
      ({required idToken, required playlist}) async => RemotePlaylist(
        id: playlist.id,
        nome: playlist.nome,
        pdfIds: playlist.pdfIds,
        salva: true,
        favorita: playlist.favorita,
        createdAt: playlist.createdAt,
        updatedAt: playlist.updatedAt,
        version: playlist.version + 1,
        savedAt: playlist.savedAt,
        favoritedAt: playlist.favoritedAt,
      ),
      ({required idToken, required playlistId}) async {},
    );

    final result = await sync(idToken: 'token');
    expect(result.pulled, 0);
    expect(result.pushed, 1);
    expect(repo.map['p1']?.nome, 'Local');
    expect(repo.map['p1']?.syncStatus, PlaylistSyncStatus.synced);
  });

  test('rascunho não sobe no push', () async {
    final repo = _MemoryPlaylistRepository();
    await repo.create(
      nome: 'Draft',
      pdfIds: const ['a'],
      playlistId: 'd1',
      salva: false,
    );

    var putCount = 0;
    final sync = SyncPlaylists(
      repo,
      (_) async => <RemotePlaylist>[],
      ({required idToken, required playlist}) async {
        putCount++;
        return playlist;
      },
      ({required idToken, required playlistId}) async {},
    );

    final result = await sync(idToken: 'token');
    expect(putCount, 0);
    expect(result.pushed, 0);
  });

  test('tombstone dispara DELETE remoto e hard delete local', () async {
    final repo = _MemoryPlaylistRepository();
    await repo.upsert(
      SavedPlaylist(
        playlistId: 'gone',
        nome: 'X',
        pdfIds: const [],
        createdAt: DateTime.utc(2026, 1, 1),
        salva: true,
        deletedAt: DateTime.utc(2026, 6, 1),
        syncStatus: PlaylistSyncStatus.pendingPush,
      ),
    );

    String? deletedId;
    final sync = SyncPlaylists(
      repo,
      (_) async => <RemotePlaylist>[],
      ({required idToken, required playlist}) async => playlist,
      ({required idToken, required playlistId}) async {
        deletedId = playlistId;
      },
    );

    final result = await sync(idToken: 'token');
    expect(deletedId, 'gone');
    expect(result.deleted, 1);
    expect(repo.map.containsKey('gone'), isFalse);
  });

  test('pull preserva metadados de publicação', () async {
    final repo = _MemoryPlaylistRepository();
    final remote = RemotePlaylist(
      id: 'pub1',
      nome: 'Evangelismo',
      pdfIds: const ['a'],
      salva: true,
      favorita: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 2, 1),
      version: 3,
      savedAt: DateTime.utc(2026, 1, 1),
      isPublished: true,
      publicationReach: PlaylistReach.pontual,
      publicationCategory: PlaylistCategory.evangelizacao,
      publishedAt: DateTime.utc(2026, 1, 15),
    );

    final sync = SyncPlaylists(
      repo,
      (_) async => [remote],
      ({required idToken, required playlist}) async => playlist,
      ({required idToken, required playlistId}) async {},
    );

    await sync(idToken: 'token');
    final local = repo.map['pub1']!;
    expect(local.isPublished, isTrue);
    expect(local.publicationReach, PlaylistReach.pontual);
    expect(local.publicationCategory, PlaylistCategory.evangelizacao);
  });
}
