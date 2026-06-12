import '../repositories/playlist_repository.dart';

/// UC-06 — Desfavoritar playlist (Fase 4.8).
class UnfavoritePlaylist {
  const UnfavoritePlaylist(this._repository);

  final PlaylistRepository _repository;

  Future<void> call({required String playlistId}) async {
    await _repository.update(
      playlistId,
      favorita: false,
      clearFavoritedAt: true,
    );
  }
}
