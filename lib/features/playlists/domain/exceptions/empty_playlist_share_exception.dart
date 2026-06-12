/// Playlist sem PDFs — não pode gerar URL de compartilhamento (UC-07).
///
/// Lançada por [GeneratePlaylistShareUrl] quando `pdfIds.isEmpty`.
class EmptyPlaylistShareException implements Exception {
  const EmptyPlaylistShareException();

  @override
  String toString() => 'EmptyPlaylistShareException';
}
