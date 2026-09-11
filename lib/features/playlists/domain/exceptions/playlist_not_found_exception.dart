/// Lançada por [GeneratePlaylistShareUrl] quando o `playlistId` pedido não
/// existe (ou já foi apagado).
class PlaylistNotFoundException implements Exception {
  const PlaylistNotFoundException();

  @override
  String toString() => 'PlaylistNotFoundException: playlist not found';
}
