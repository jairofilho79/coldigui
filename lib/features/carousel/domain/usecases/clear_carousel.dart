import '../repositories/carousel_repository.dart';

/// UC-05 — Limpar carousel (Fase 4.1).
///
/// Remove todas as entradas Isar — idempotente.
class ClearCarousel {
  const ClearCarousel(this._repository);

  final CarouselRepository _repository;

  Future<void> call() => _repository.clear();
}
