import 'package:coldigui/core/database/collections/playlist_sync_status.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/publish_playlist.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements PlaylistRepository {
  SavedPlaylist? playlist;

  @override
  Future<String> create({
    required String nome,
    required List<String> pdfIds,
    String? playlistId,
    DateTime? createdAt,
    bool salva = true,
    DateTime? savedAt,
    DateTime? updatedAt,
    int version = 1,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String playlistId) => throw UnimplementedError();

  @override
  Future<void> deleteAllUnsaved() => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getAll() => throw UnimplementedError();

  @override
  Future<SavedPlaylist?> getById(String playlistId) async => playlist;

  @override
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab) =>
      throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getPendingPush() => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getTombstones() => throw UnimplementedError();

  @override
  Future<void> hardDelete(String playlistId) => throw UnimplementedError();

  @override
  Future<void> markAllSavedPendingPush() => throw UnimplementedError();

  @override
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) async {
    final existing = playlist;
    if (existing == null) throw StateError('missing');
    if (!existing.salva)
      throw StateError('Only saved playlists can be published');
    if (existing.isPublished) {
      throw StateError('Playlist already published: $playlistId');
    }
    playlist = existing.copyWith(
      isPublished: true,
      publicationCategory: category,
      publicationReach: reach,
      publishedAt: DateTime.utc(2026, 7, 13),
      syncStatus: PlaylistSyncStatus.pendingPush,
    );
  }

  @override
  Future<void> update(
    String playlistId, {
    String? nome,
    List<String>? pdfIds,
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
  Future<void> upsert(SavedPlaylist playlist) async {
    this.playlist = playlist;
  }
}

void main() {
  test('publica com usual por padrão e marca pendingPush', () async {
    final repo = _Repo()
      ..playlist = SavedPlaylist(
        playlistId: 'p1',
        nome: 'Culto',
        pdfIds: const ['a'],
        createdAt: DateTime.utc(2026, 1, 1),
        salva: true,
      );

    await PublishPlaylist(repo)(
      playlistId: 'p1',
      category: PlaylistCategory.evangelizacao,
    );

    expect(repo.playlist?.isPublished, isTrue);
    expect(repo.playlist?.publicationReach, PlaylistReach.usual);
    expect(repo.playlist?.publicationCategory, PlaylistCategory.evangelizacao);
    expect(repo.playlist?.syncStatus, PlaylistSyncStatus.pendingPush);
  });

  test('rejeita republicar', () async {
    final repo = _Repo()
      ..playlist = SavedPlaylist(
        playlistId: 'p1',
        nome: 'Culto',
        pdfIds: const ['a'],
        createdAt: DateTime.utc(2026, 1, 1),
        salva: true,
        isPublished: true,
        publicationCategory: PlaylistCategory.medleys,
        publicationReach: PlaylistReach.pontual,
        publishedAt: DateTime.utc(2026, 6, 1),
      );

    expect(
      () => PublishPlaylist(repo)(
        playlistId: 'p1',
        category: PlaylistCategory.aprendizado,
      ),
      throwsStateError,
    );
  });

  test('rejeita rascunho', () async {
    final repo = _Repo()
      ..playlist = SavedPlaylist(
        playlistId: 'd1',
        nome: 'Draft',
        pdfIds: const ['a'],
        createdAt: DateTime.utc(2026, 1, 1),
        salva: false,
      );

    expect(
      () => PublishPlaylist(repo)(
        playlistId: 'd1',
        category: PlaylistCategory.aprendizado,
      ),
      throwsStateError,
    );
  });
}
