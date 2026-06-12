/// Posição do louvor atual dentro do carousel no leitor (UC-11, Fase 4.7).
///
/// [previousPdfId] e [nextPdfId] são `null` nas extremidades — sem wrap circular.
/// Consumida por [readerCarouselPositionProvider] e [CarouselChips] no modo leitor.
class CarouselReaderPosition {
  const CarouselReaderPosition({
    required this.currentIndex,
    required this.total,
    this.previousPdfId,
    this.nextPdfId,
  });

  /// Índice 1-based na seleção ordenada.
  final int currentIndex;

  /// Total de itens no carousel.
  final int total;

  /// PDF anterior ou `null` no primeiro item.
  final String? previousPdfId;

  /// Próximo PDF ou `null` no último item.
  final String? nextPdfId;

  bool get canGoPrevious => previousPdfId != null;

  bool get canGoNext => nextPdfId != null;
}

/// Direção de navegação no carousel do leitor.
enum CarouselReaderDirection {
  previous,
  next,
}
