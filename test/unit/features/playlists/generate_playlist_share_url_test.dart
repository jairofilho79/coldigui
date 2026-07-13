import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/exceptions/empty_playlist_share_exception.dart';
import 'package:coldigui/features/playlists/domain/exceptions/playlist_not_found_exception.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/generate_playlist_share_url.dart';
import 'package:coldigui/core/database/collections/playlist_sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository(this._playlists);

  final Map<String, SavedPlaylist> _playlists;

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
  Future<void> hardDelete(String playlistId) => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getAll() => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab) =>
      throw UnimplementedError();

  @override
  Future<SavedPlaylist?> getById(String playlistId) async =>
      _playlists[playlistId];

  @override
  Future<List<SavedPlaylist>> getPendingPush() => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getTombstones() => throw UnimplementedError();

  @override
  Future<void> markAllSavedPendingPush() => throw UnimplementedError();

  @override
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) => throw UnimplementedError();

  @override
  Future<void> upsert(SavedPlaylist playlist) => throw UnimplementedError();

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
}

void main() {
  const origin = 'https://plpcg.com';

  test('gera URL com pdfIds e nome da playlist', () async {
    final useCase = GeneratePlaylistShareUrl(
      _FakePlaylistRepository({
        'p1': SavedPlaylist(
          playlistId: 'p1',
          nome: 'Ensaio',
          pdfIds: const ['a', 'b'],
          createdAt: DateTime(2026, 1, 1),
        ),
      }),
      shareOrigin: origin,
    );

    final url = await useCase(playlistId: 'p1');
    expect(url, contains('sharepdfs='));
    expect(url, contains('sharename='));
  });

  test('lança PlaylistNotFoundException quando ausente', () async {
    final useCase = GeneratePlaylistShareUrl(
      _FakePlaylistRepository({}),
      shareOrigin: origin,
    );

    expect(
      () => useCase(playlistId: 'missing'),
      throwsA(isA<PlaylistNotFoundException>()),
    );
  });

  test('lança EmptyPlaylistShareException quando pdfIds vazio', () async {
    final useCase = GeneratePlaylistShareUrl(
      _FakePlaylistRepository({
        'p1': SavedPlaylist(
          playlistId: 'p1',
          nome: 'Vazia',
          pdfIds: const [],
          createdAt: DateTime(2026, 1, 1),
        ),
      }),
      shareOrigin: origin,
    );

    expect(
      () => useCase(playlistId: 'p1'),
      throwsA(isA<EmptyPlaylistShareException>()),
    );
  });
}
