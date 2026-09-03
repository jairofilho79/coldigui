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
    List<String> audioIds = const [],
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
      ..items = <String>[...pdfIds, ...audioIds]
      ..pdfIds = List<String>.from(pdfIds)
      ..audioIds = List<String>.from(audioIds)
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

  /// [pdfIds]/[audioIds] substituem apenas o seu subconjunto da ordem única —
  /// ver [SavedPlaylist.replaceSubset]. Um reorder da face de partituras
  /// vindo do carousel não move os áudios de lugar.
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
    final existing = await getById(playlistId);
    final becomesSaved = salva == true || (existing?.salva ?? false);
    final touchSync =
        nome != null ||
        pdfIds != null ||
        audioIds != null ||
        salva != null ||
        savedAt != null ||
        favoritedAt != null ||
        favorita != null ||
        clearFavoritedAt ||
        deletedAt != null;

    // Reprojeta a ordem única antes de escrever: as duas listas gravadas em
    // disco continuam sendo projeções coerentes de `items`.
    SavedPlaylist? next;
    if ((pdfIds != null || audioIds != null) && existing != null) {
      next = existing.copyWith(pdfIds: pdfIds, audioIds: audioIds);
    }

    await _local.updateFields(
      playlistId,
      nome: nome,
      items: next?.items,
      pdfIds: next?.pdfIds ?? pdfIds,
      audioIds: next?.audioIds ?? audioIds,
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
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) async {
    final existing = await getById(playlistId);
    if (existing == null) {
      throw StateError('Playlist not found: $playlistId');
    }
    if (!existing.salva) {
      throw StateError('Only saved playlists can be published');
    }
    if (existing.isPublished) {
      throw StateError('Playlist already published: $playlistId');
    }
    final now = DateTime.now().toUtc();
    await _local.updateFields(
      playlistId,
      isPublished: true,
      publicationReachIndex: reach.index,
      publicationCategoryIndex: category.index,
      publishedAt: now,
      updatedAt: now,
      syncStatus: PlaylistSyncStatus.pendingPush,
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
      ..items = List<String>.from(playlist.items)
      ..pdfIds = List<String>.from(playlist.pdfIds)
      ..audioIds = List<String>.from(playlist.audioIds)
      ..createdAt = playlist.createdAt
      ..salva = playlist.salva
      ..savedAt = playlist.savedAt
      ..favoritedAt = playlist.favoritedAt
      ..favorita = playlist.favorita
      ..updatedAt = playlist.updatedAt
      ..version = playlist.version
      ..syncStatus = playlist.syncStatus
      ..deletedAt = playlist.deletedAt
      ..isPublished = playlist.isPublished
      ..publicationReach = playlist.publicationReach
      ..publicationCategory = playlist.publicationCategory
      ..publishedAt = playlist.publishedAt;
    await _local.insert(row);
  }

  @override
  Future<void> markAllSavedPendingPush() => _local.markAllSavedPendingPush();

  SavedPlaylist _toEntity(Playlist row) => SavedPlaylist(
    playlistId: row.playlistId,
    // `items` já vem migrado do datasource; o fallback cobre a lista vazia.
    items: row.items.isNotEmpty
        ? List<String>.from(row.items)
        : <String>[...row.pdfIds, ...row.audioIds],
    nome: row.nome,
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
    isPublished: row.isPublished,
    publicationReach: row.publicationReach,
    publicationCategory: row.publicationCategory,
    publishedAt: row.publishedAt,
  );
}
