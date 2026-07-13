import '../../../../core/database/collections/playlist.dart';
import '../../domain/entities/playlist_tab.dart';
import '../../domain/entities/saved_playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../domain/utils/playlist_defaults.dart';
import '../datasources/playlist_local_datasource.dart';

/// Orquestra [PlaylistLocalDatasource] (UC-06 + UC-15).
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
    DateTime? updatedAt,
    int version = 1,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
  }) async {
    final id = playlistId ?? generatePlaylistId();
    final now = createdAt ?? DateTime.now();
    final effectiveUpdatedAt = updatedAt ?? now;
    final row = Playlist()
      ..playlistId = id
      ..nome = nome
      ..pdfIds = List<String>.from(pdfIds)
      ..createdAt = now
      ..salva = salva
      ..savedAt = savedAt ?? (salva ? now : null)
      ..favorita = false
      ..updatedAt = effectiveUpdatedAt
      ..version = version
      ..syncStatus = salva && syncStatus == PlaylistSyncStatus.synced
          ? PlaylistSyncStatus.pendingPush
          : syncStatus;

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
    DateTime? updatedAt,
    int? version,
    PlaylistSyncStatus? syncStatus,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) async {
    final existing = await getById(playlistId);
    final becomesSaved = salva == true || (existing?.salva ?? false);
    final touchSync =
        nome != null ||
        pdfIds != null ||
        salva != null ||
        savedAt != null ||
        favoritedAt != null ||
        favorita != null ||
        clearFavoritedAt ||
        deletedAt != null;

    await _local.updateFields(
      playlistId,
      nome: nome,
      pdfIds: pdfIds,
      salva: salva,
      savedAt: savedAt,
      favoritedAt: favoritedAt,
      favorita: favorita,
      clearFavoritedAt: clearFavoritedAt,
      updatedAt: updatedAt ?? (touchSync ? DateTime.now().toUtc() : null),
      version: version,
      syncStatus:
          syncStatus ??
          (touchSync && becomesSaved ? PlaylistSyncStatus.pendingPush : null),
      deletedAt: deletedAt,
      clearDeletedAt: clearDeletedAt,
    );
  }

  @override
  Future<void> delete(String playlistId) async {
    final existing = await getById(playlistId);
    if (existing == null) return;
    if (existing.salva) {
      await _local.softDeleteByPlaylistId(playlistId);
    } else {
      await _local.deleteByPlaylistId(playlistId);
    }
  }

  @override
  Future<void> hardDelete(String playlistId) =>
      _local.deleteByPlaylistId(playlistId);

  @override
  Future<void> deleteAllUnsaved() => _local.deleteAllUnsaved();

  @override
  Future<List<SavedPlaylist>> getPendingPush() async {
    final rows = await _local.findPendingPush();
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<List<SavedPlaylist>> getTombstones() async {
    final rows = await _local.findTombstones();
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<void> upsert(SavedPlaylist playlist) async {
    final row = Playlist()
      ..playlistId = playlist.playlistId
      ..nome = playlist.nome
      ..pdfIds = List<String>.from(playlist.pdfIds)
      ..createdAt = playlist.createdAt
      ..salva = playlist.salva
      ..savedAt = playlist.savedAt
      ..favoritedAt = playlist.favoritedAt
      ..favorita = playlist.favorita
      ..updatedAt = playlist.updatedAt
      ..version = playlist.version
      ..syncStatus = playlist.syncStatus
      ..deletedAt = playlist.deletedAt;
    await _local.insert(row);
  }

  @override
  Future<void> markAllSavedPendingPush() => _local.markAllSavedPendingPush();

  SavedPlaylist _toEntity(Playlist row) => SavedPlaylist(
    playlistId: row.playlistId,
    nome: row.nome,
    pdfIds: List<String>.from(row.pdfIds),
    createdAt: row.createdAt,
    salva: row.salva,
    savedAt: row.savedAt,
    favoritedAt: row.favoritedAt,
    favorita: row.favorita,
    updatedAt: row.updatedAt.millisecondsSinceEpoch == 0
        ? row.createdAt
        : row.updatedAt,
    version: row.version,
    syncStatus: row.syncStatus,
    deletedAt: row.deletedAt,
  );
}
