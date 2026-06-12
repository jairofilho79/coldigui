import 'package:isar/isar.dart';

import '../../../../core/database/collections/playlist.dart';

/// CRUD Isar para [Playlist] (UC-06, Fase 4.2 + 4.8).
///
/// Queries por aba: [findUnsaved], [findSaved], [findFavorites].
class PlaylistLocalDatasource {
  const PlaylistLocalDatasource(this._isar);

  final Isar _isar;

  Future<List<Playlist>> findAll() => _isar.playlists.where().findAll();

  /// Não salvas — `createdAt` desc.
  Future<List<Playlist>> findUnsaved() => _isar.playlists
      .filter()
      .salvaEqualTo(false)
      .sortByCreatedAtDesc()
      .findAll();

  /// Salvas (não favoritas) — `savedAt` desc.
  Future<List<Playlist>> findSaved() => _isar.playlists
      .filter()
      .salvaEqualTo(true)
      .and()
      .favoritaEqualTo(false)
      .sortBySavedAtDesc()
      .findAll();

  /// Favoritas — `favoritedAt` desc.
  Future<List<Playlist>> findFavorites() => _isar.playlists
      .filter()
      .favoritaEqualTo(true)
      .sortByFavoritedAtDesc()
      .findAll();

  Future<Playlist?> findByPlaylistId(String playlistId) =>
      _isar.playlists.getByPlaylistId(playlistId);

  Future<void> insert(Playlist playlist) async {
    await _isar.writeTxn(() async {
      await _isar.playlists.putByPlaylistId(playlist);
    });
  }

  Future<void> updateFields(
    String playlistId, {
    String? nome,
    List<String>? pdfIds,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
    bool clearFavoritedAt = false,
  }) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.playlists.getByPlaylistId(playlistId);
      if (existing == null) {
        throw StateError('Playlist not found: $playlistId');
      }

      if (nome != null) existing.nome = nome;
      if (pdfIds != null) existing.pdfIds = List<String>.from(pdfIds);
      if (salva != null) existing.salva = salva;
      if (savedAt != null) existing.savedAt = savedAt;
      if (favoritedAt != null) existing.favoritedAt = favoritedAt;
      if (clearFavoritedAt) existing.favoritedAt = null;
      if (favorita != null) existing.favorita = favorita;

      await _isar.playlists.put(existing);
    });
  }

  /// Idempotente se [playlistId] ausente.
  Future<void> deleteByPlaylistId(String playlistId) async {
    await _isar.writeTxn(() async {
      await _isar.playlists.deleteByPlaylistId(playlistId);
    });
  }

  Future<void> deleteAllUnsaved() async {
    await _isar.writeTxn(() async {
      final rows = await _isar.playlists.filter().salvaEqualTo(false).findAll();
      for (final row in rows) {
        await _isar.playlists.delete(row.id);
      }
    });
  }
}
