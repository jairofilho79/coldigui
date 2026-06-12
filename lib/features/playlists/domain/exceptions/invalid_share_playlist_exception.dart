/// Params de importação inválidos (UC-07).
///
/// Lançada por [ImportSharedPlaylistFromUrl] quando CSV vazio ou nome em branco.
class InvalidSharePlaylistException implements Exception {
  const InvalidSharePlaylistException();

  @override
  String toString() => 'InvalidSharePlaylistException';
}
