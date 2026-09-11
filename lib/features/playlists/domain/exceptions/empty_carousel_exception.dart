/// Lançada ao gerar folheto de uma seleção sem partituras (UC-08).
class EmptyCarouselException implements Exception {
  const EmptyCarouselException();

  @override
  String toString() => 'EmptyCarouselException: carousel has no items';
}
