/// Lançada quando [CreatePlaylistFromCarousel] é chamado com carousel vazio.
class EmptyCarouselException implements Exception {
  const EmptyCarouselException();

  @override
  String toString() => 'EmptyCarouselException: carousel has no items';
}
