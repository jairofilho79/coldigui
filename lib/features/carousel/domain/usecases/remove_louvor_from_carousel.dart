import '../repositories/carousel_repository.dart';

/// UC-05 — Remover louvor do carousel (Fase 4.1).
///
/// Idempotente se [pdfId] não está na seleção.
class RemoveLouvorFromCarousel {
  const RemoveLouvorFromCarousel(this._repository);

  final CarouselRepository _repository;

  Future<void> call({required String pdfId}) => _repository.remove(pdfId);
}
