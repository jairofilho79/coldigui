import '../entities/carousel_item.dart';

/// Contrato de persistência do carousel temporário (UC-05).
abstract class CarouselRepository {
  /// Entradas ordenadas por [CarouselItem.sortOrder].
  ///
  /// [pdfIdToMetadata] enriquece campos de UI do manifest; entradas ausentes
  /// recebem fallback de [CarouselRepositoryImpl].
  Future<List<CarouselItem>> getOrderedItems({
    required Map<String, CarouselItemMetadata> pdfIdToMetadata,
  });

  /// IDs ordenados — útil para Fase 4.2+.
  Future<List<String>> getOrderedPdfIds();

  /// Adiciona ao final; no-op se [pdfId] já existe.
  Future<void> add(String pdfId);

  /// Remove por [pdfId] e compacta ordem — idempotente se ausente.
  Future<void> remove(String pdfId);

  /// Troca [oldPdfId] por [newPdfId] na mesma posição; dedupe se [newPdfId] já existe.
  Future<bool> replacePdfId(String oldPdfId, String newPdfId);

  /// Reordena validando que o conjunto de IDs é idêntico ao atual.
  Future<void> reorder(List<String> orderedPdfIds);

  /// Substitui toda a seleção — usado por [LoadPlaylistIntoCarousel] (Fase 4.3).
  ///
  /// Equivalente a `clear` + insert sequencial com `sortOrder` 0..n-1.
  Future<void> replaceAll(List<String> orderedPdfIds);

  /// Remove todas as entradas — idempotente.
  Future<void> clear();
}
