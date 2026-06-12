/// Lançada quando [LoadPlaylistIntoCarousel] é chamado com [playlistId] ausente.
class PlaylistNotFoundException implements Exception {
  const PlaylistNotFoundException();

  @override
  String toString() => 'PlaylistNotFoundException: playlist not found';
}
