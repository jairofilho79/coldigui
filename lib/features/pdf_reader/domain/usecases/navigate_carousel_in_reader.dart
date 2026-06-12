import '../../../carousel/domain/repositories/carousel_repository.dart';
import '../entities/carousel_reader_position.dart';

/// UC-11 — Navegar carousel no leitor (Fase 4.7).
class NavigateCarouselInReader {
  const NavigateCarouselInReader(this._carouselRepository);

  final CarouselRepository _carouselRepository;

  /// Retorna posição de [currentPdfId] na seleção ou `null` se carousel vazio
  /// ou PDF fora da seleção.
  Future<CarouselReaderPosition?> getPosition({
    required String currentPdfId,
  }) async {
    final orderedPdfIds = await _carouselRepository.getOrderedPdfIds();
    if (orderedPdfIds.isEmpty) return null;

    final index = orderedPdfIds.indexOf(currentPdfId);
    if (index < 0) return null;

    final total = orderedPdfIds.length;

    return CarouselReaderPosition(
      currentIndex: index + 1,
      total: total,
      previousPdfId: index > 0 ? orderedPdfIds[index - 1] : null,
      nextPdfId: index < total - 1 ? orderedPdfIds[index + 1] : null,
    );
  }

  /// Resolve o [pdfId] alvo para [direction] ou `null` se indisponível.
  Future<String?> resolveTarget({
    required String currentPdfId,
    required CarouselReaderDirection direction,
  }) async {
    final position = await getPosition(currentPdfId: currentPdfId);
    if (position == null) return null;

    return switch (direction) {
      CarouselReaderDirection.previous => position.previousPdfId,
      CarouselReaderDirection.next => position.nextPdfId,
    };
  }
}
