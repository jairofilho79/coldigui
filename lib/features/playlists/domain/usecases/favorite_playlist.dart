import '../repositories/playlist_repository.dart';

/// UC-06 — Favoritar playlist salva (Fase 4.8).
class FavoritePlaylist {
  const FavoritePlaylist(this._repository);

  final PlaylistRepository _repository;

  Future<void> call({required String playlistId}) async {
    final playlist = await _repository.getById(playlistId);
    if (playlist == null) {
      throw StateError('Playlist not found: $playlistId');
    }
    if (!playlist.salva) {
      throw StateError('Cannot favorite unsaved playlist: $playlistId');
    }

    await _repository.update(
      playlistId,
      favorita: true,
      favoritedAt: DateTime.now(),
    );
  }
}
