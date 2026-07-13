import '../entities/saved_playlist.dart';
import '../repositories/playlist_repository.dart';

/// Publica lista salva (irreversível) com categoria e alcance.
class PublishPlaylist {
  const PublishPlaylist(this._repository);

  final PlaylistRepository _repository;

  Future<void> call({
    required String playlistId,
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) {
    return _repository.publish(playlistId, category: category, reach: reach);
  }
}
