import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/playlist.dart';

/// CRUD Isar para [Playlist] (UC-06, Fase 4.2 + 4.8).
///
/// Queries por aba: [findUnsaved], [findSaved], [findFavorites].
class PlaylistLocalDatasource {
  const PlaylistLocalDatasource(this._isar);

  const PlaylistLocalDatasource.unavailable() : _isar = null;

  final Isar? _isar;

  Future<List<Playlist>> findAll() async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.playlists.where().findAll();
  }

  /// Não salvas — `createdAt` desc.
  Future<List<Playlist>> findUnsaved() async {
    final isar = _isar;
    if (isar == null) return const [];
    return isar.playlists
        .where()
        .salvaEqualTo(false)
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
        .sortByFavoritedAtDesc()
        .findAll();
  }

  Future<Playlist?> findByPlaylistId(String playlistId) async {
    final isar = _isar;
    if (isar == null) return null;
    return isar.playlists.where().playlistIdEqualTo(playlistId).findFirst();
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
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
    bool clearFavoritedAt = false,
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
      if (salva != null) existing.salva = salva;
      if (savedAt != null) existing.savedAt = savedAt;
      if (favoritedAt != null) existing.favoritedAt = favoritedAt;
      if (clearFavoritedAt) existing.favoritedAt = null;
      if (favorita != null) existing.favorita = favorita;

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
      final rows = coll.where().salvaEqualTo(false).findAll();
      for (final row in rows) {
        coll.delete(row.id);
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
