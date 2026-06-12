import '../repositories/carousel_repository.dart';

/// UC-05 — Adicionar louvor ao carousel (Fase 4.1).
///
/// Retorna `true` se inseriu; `false` se [pdfId] já estava na seleção (no-op).
class AddLouvorToCarousel {
  const AddLouvorToCarousel(this._repository);

  final CarouselRepository _repository;

  Future<bool> call({required String pdfId}) async {
    final before = await _repository.getOrderedPdfIds();
    if (before.contains(pdfId)) return false;

    await _repository.add(pdfId);
    return true;
  }
}
