import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/playlist.dart';
import '../../../../core/database/collections/playlist_sync_status.dart';

/// CRUD Isar para [Playlist] (UC-06 + UC-15 sync).
///
/// Queries por aba excluem tombstones (`deletedAt != null`).
class PlaylistLocalDatasource {
  const PlaylistLocalDatasource(this._isar);

  const PlaylistLocalDatasource.unavailable() : _isar = null;

  final Isar? _isar;

  Future<List<Playlist>> findAll() async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.playlists.where().deletedAtIsNull().findAll();
  }

  /// Não salvas — `createdAt` desc.
  Future<List<Playlist>> findUnsaved() async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.playlists
        .where()
        .salvaEqualTo(false)
        .and()
        .deletedAtIsNull()
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// Salvas (não favoritas) — `savedAt` desc.
  Future<List<Playlist>> findSaved() async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.playlists
        .where()
        .salvaEqualTo(true)
        .and()
        .favoritaEqualTo(false)
        .and()
        .deletedAtIsNull()
        .sortBySavedAtDesc()
        .findAll();
  }

  /// Favoritas — `favoritedAt` desc.
  Future<List<Playlist>> findFavorites() async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.playlists
        .where()
        .favoritaEqualTo(true)
        .and()
        .deletedAtIsNull()
        .sortByFavoritedAtDesc()
        .findAll();
  }

  Future<Playlist?> findByPlaylistId(String playlistId) async {
    final isar = _isar;
    if (isar == null) return null;
    return isar.playlists.where().playlistIdEqualTo(playlistId).findFirst();
  }

  Future<List<Playlist>> findPendingPush() async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.playlists
        .where()
        .syncStatusIndexEqualTo(PlaylistSyncStatus.pendingPush.index)
        .and()
        .salvaEqualTo(true)
        .and()
        .deletedAtIsNull()
        .findAll();
  }

  Future<List<Playlist>> findTombstones() async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.playlists
        .where()
        .deletedAtIsNotNull()
        .and()
        .syncStatusIndexEqualTo(PlaylistSyncStatus.pendingPush.index)
        .findAll();
  }

  Future<List<Playlist>> findAllSavedIncludingDeleted() async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.playlists.where().salvaEqualTo(true).findAll();
  }

  Future<void> insert(Playlist playlist) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.write((isar) {
      _putByPlaylistId(isar.playlists, playlist);
    });
  }

  Future<void> updateFields(
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
    bool? isPublished,
    int? publicationReachIndex,
    int? publicationCategoryIndex,
    DateTime? publishedAt,
    bool clearPublication = false,
  }) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.write((isar) {
      final coll = isar.playlists;
      final existing = coll.where().playlistIdEqualTo(playlistId).findFirst();
      if (existing == null) {
        throw StateError('Playlist not found: $playlistId');
      }

      if (nome != null) existing.nome = nome;
      if (pdfIds != null) existing.pdfIds = List<String>.from(pdfIds);
      if (audioIds != null) existing.audioIds = List<String>.from(audioIds);
      if (salva != null) existing.salva = salva;
      if (savedAt != null) existing.savedAt = savedAt;
      if (favoritedAt != null) existing.favoritedAt = favoritedAt;
      if (clearFavoritedAt) existing.favoritedAt = null;
      if (favorita != null) existing.favorita = favorita;
      if (updatedAt != null) existing.updatedAt = updatedAt;
      if (version != null) existing.version = version;
      if (syncStatus != null) existing.syncStatus = syncStatus;
      if (clearDeletedAt) {
        existing.deletedAt = null;
      } else if (deletedAt != null) {
        existing.deletedAt = deletedAt;
      }
      if (clearPublication) {
        existing.isPublished = false;
        existing.publicationReachIndex = null;
        existing.publicationCategoryIndex = null;
        existing.publishedAt = null;
      } else {
        if (isPublished != null) existing.isPublished = isPublished;
        if (publicationReachIndex != null) {
          existing.publicationReachIndex = publicationReachIndex;
        }
        if (publicationCategoryIndex != null) {
          existing.publicationCategoryIndex = publicationCategoryIndex;
        }
        if (publishedAt != null) existing.publishedAt = publishedAt;
      }

      coll.put(existing);
    });
  }

  /// Soft delete: tombstone + pendingPush (listas salvas).
  Future<void> softDeleteByPlaylistId(String playlistId) async {
    final isar = _isar;
    if (isar == null) return;
    final now = DateTime.now().toUtc();
    await isar.write((isar) {
      final coll = isar.playlists;
      final existing = coll.where().playlistIdEqualTo(playlistId).findFirst();
      if (existing == null) return;
      existing.deletedAt = now;
      existing.updatedAt = now;
      existing.syncStatus = PlaylistSyncStatus.pendingPush;
      coll.put(existing);
    });
  }

  /// Idempotente se [playlistId] ausente.
  Future<void> deleteByPlaylistId(String playlistId) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.write((isar) {
      final coll = isar.playlists;
      final existing = coll.where().playlistIdEqualTo(playlistId).findFirst();
      if (existing != null) {
        coll.delete(existing.id);
      }
    });
  }

  Future<void> deleteAllUnsaved() async {
    final isar = _isar;
    if (isar == null) return;
    await isar.write((isar) {
      final coll = isar.playlists;
      final rows = coll
          .where()
          .salvaEqualTo(false)
          .and()
          .deletedAtIsNull()
          .findAll();
      for (final row in rows) {
        coll.delete(row.id);
      }
    });
  }

  Future<void> markAllSavedPendingPush() async {
    final isar = _isar;
    if (isar == null) return;
    await isar.write((isar) {
      final coll = isar.playlists;
      final rows = coll
          .where()
          .salvaEqualTo(true)
          .and()
          .deletedAtIsNull()
          .findAll();
      for (final row in rows) {
        row.syncStatus = PlaylistSyncStatus.pendingPush;
        coll.put(row);
      }
    });
  }

  void _putByPlaylistId(IsarCollection<int, Playlist> coll, Playlist playlist) {
    final existing = coll
        .where()
        .playlistIdEqualTo(playlist.playlistId)
        .findFirst();
    if (existing != null) {
      playlist.id = existing.id;
    } else if (playlist.id == 0) {
      playlist.id = coll.autoIncrement();
    }
    coll.put(playlist);
  }
}
