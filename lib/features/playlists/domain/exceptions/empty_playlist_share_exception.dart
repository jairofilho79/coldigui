/// Playlist sem nada para o link — não pode gerar URL de compartilhamento
/// (UC-07).
///
/// Lançada por [GeneratePlaylistShareUrl] quando a lista não tem entradas ou
/// só tem ids legados fora do Coldigom.
class EmptyPlaylistShareException implements Exception {
  const EmptyPlaylistShareException();

  @override
  String toString() => 'EmptyPlaylistShareException';
}
