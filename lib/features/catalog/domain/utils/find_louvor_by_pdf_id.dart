import '../entities/louvor.dart';

/// Lookup O(n) de louvor no manifest por [pdfId].
///
/// Retorna `null` se [catalog] for `null` ou se o id for órfão.
/// Usado por [ReaderCarouselActionsNotifier] (4.7) e [PlaylistsNotifier].
Louvor? findLouvorByPdfId(List<Louvor>? catalog, String pdfId) {
  if (catalog == null) return null;
  for (final louvor in catalog) {
    if (louvor.pdfId == pdfId) return louvor;
  }
  return null;
}
