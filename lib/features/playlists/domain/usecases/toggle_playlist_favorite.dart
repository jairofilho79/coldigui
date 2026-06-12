import '../repositories/playlist_repository.dart';

/// UC-06 — Alternar favorito da playlist (Fase 4.2).
class TogglePlaylistFavorite {
  const TogglePlaylistFavorite(this._repository);

  final PlaylistRepository _repository;

  /// Retorna o novo valor de [favorita].
  Future<bool> call({required String playlistId}) async {
    final playlist = await _repository.getById(playlistId);
    if (playlist == null) {
      throw StateError('Playlist not found: $playlistId');
    }

    final next = !playlist.favorita;
    await _repository.update(playlistId, favorita: next);
    return next;
  }
}
