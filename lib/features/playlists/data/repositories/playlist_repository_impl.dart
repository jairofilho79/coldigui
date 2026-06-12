import '../../../../core/database/collections/playlist.dart';
import '../../domain/entities/playlist_tab.dart';
import '../../domain/entities/saved_playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../domain/utils/playlist_defaults.dart';
import '../datasources/playlist_local_datasource.dart';

/// Orquestra [PlaylistLocalDatasource] (UC-06, Fase 4.2).
class PlaylistRepositoryImpl implements PlaylistRepository {
  const PlaylistRepositoryImpl(this._local);

  final PlaylistLocalDatasource _local;

  @override
  Future<List<SavedPlaylist>> getAll() async {
    final rows = await _local.findAll();
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab) async {
    final rows = switch (tab) {
      PlaylistTab.unsaved => await _local.findUnsaved(),
      PlaylistTab.saved => await _local.findSaved(),
      PlaylistTab.favorites => await _local.findFavorites(),
    };
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<SavedPlaylist?> getById(String playlistId) async {
    final row = await _local.findByPlaylistId(playlistId);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<String> create({
    required String nome,
    required List<String> pdfIds,
    String? playlistId,
    DateTime? createdAt,
    bool salva = true,
    DateTime? savedAt,
  }) async {
    final id = playlistId ?? generatePlaylistId();
    final now = createdAt ?? DateTime.now();
    final row = Playlist()
      ..playlistId = id
      ..nome = nome
      ..pdfIds = List<String>.from(pdfIds)
      ..createdAt = now
      ..salva = salva
      ..savedAt = savedAt ?? (salva ? now : null)
      ..favorita = false;

    await _local.insert(row);
    return id;
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
  }) =>
      _local.updateFields(
        playlistId,
        nome: nome,
        pdfIds: pdfIds,
        salva: salva,
        savedAt: savedAt,
        favoritedAt: favoritedAt,
        favorita: favorita,
        clearFavoritedAt: clearFavoritedAt,
      );

  @override
  Future<void> delete(String playlistId) =>
      _local.deleteByPlaylistId(playlistId);

  @override
  Future<void> deleteAllUnsaved() => _local.deleteAllUnsaved();

  SavedPlaylist _toEntity(Playlist row) => SavedPlaylist(
        playlistId: row.playlistId,
        nome: row.nome,
        pdfIds: List<String>.from(row.pdfIds),
        createdAt: row.createdAt,
        salva: row.salva,
        savedAt: row.savedAt,
        favoritedAt: row.favoritedAt,
        favorita: row.favorita,
      );
}
