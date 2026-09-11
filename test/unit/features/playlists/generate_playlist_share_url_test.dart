import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/exceptions/empty_playlist_share_exception.dart';
import 'package:coldigui/features/playlists/domain/exceptions/playlist_not_found_exception.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/generate_playlist_share_url.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository(this._playlists);

  final Map<String, SavedPlaylist> _playlists;

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
  Future<List<SavedPlaylist>> getPendingPush({String? sub}) =>
      throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getTombstones() => throw UnimplementedError();

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
  Future<void> upsert(SavedPlaylist playlist) => throw UnimplementedError();

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
}

void main() {
  const origin = 'https://plpcg.com';

  test('gera URL com pdfIds e nome da playlist', () async {
    final useCase = GeneratePlaylistShareUrl(
      _FakePlaylistRepository({
        'p1': SavedPlaylist.fromLegacyLists(
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

  test('emite shareitems com a ordem intercalada da playlist', () async {
    const entries = [
      PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf),
      PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio),
      PlaylistEntry(id: 'cif-1', kind: MaterialKind.chord),
    ];
    final useCase = GeneratePlaylistShareUrl(
      _FakePlaylistRepository({
        'p1': SavedPlaylist(
          playlistId: 'p1',
          nome: 'Ensaio',
          entries: entries,
          createdAt: DateTime(2026, 1, 1),
        ),
      }),
      shareOrigin: origin,
    );

    final url = await useCase(playlistId: 'p1');
    final params = parsePlaylistShareParams(Uri.parse(url));
    expect(params!.entries, entries);
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
        'p1': SavedPlaylist.fromLegacyLists(
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
