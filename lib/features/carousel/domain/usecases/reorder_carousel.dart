import '../repositories/carousel_repository.dart';

/// UC-05 — Reordenar carousel (Fase 4.1).
///
/// [orderedPdfIds] deve conter exatamente os mesmos IDs da seleção atual.
class ReorderCarousel {
  const ReorderCarousel(this._repository);

  final CarouselRepository _repository;

  Future<void> call({required List<String> orderedPdfIds}) =>
      _repository.reorder(orderedPdfIds);
}
