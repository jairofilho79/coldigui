import '../../../carousel/domain/entities/carousel_item.dart';
import '../../../carousel/domain/repositories/carousel_repository.dart';
import '../../../playlists/domain/exceptions/empty_carousel_exception.dart';
import '../entities/leaflet_document.dart';

/// UC-08 — Gerar folheto da seleção atual do carousel (Fase 4.6).
///
/// Lê a seleção ordenada via [CarouselRepository] e retorna [LeafletDocument].
/// Lança [EmptyCarouselException] se não houver louvores na seleção.
class GenerateLeafletFromSelection {
  const GenerateLeafletFromSelection(this._carouselRepository);

  final CarouselRepository _carouselRepository;

  /// Retorna documento com número/nome por louvor para captura/impressão.
  ///
  /// [pdfIdToMetadata] enriquece itens do manifest; mapa vazio usa fallback do
  /// repositório.
  Future<LeafletDocument> call({
    Map<String, CarouselItemMetadata>? pdfIdToMetadata,
    DateTime? generatedAt,
  }) async {
    final items = await _carouselRepository.getOrderedItems(
      pdfIdToMetadata: pdfIdToMetadata ?? const {},
    );
    if (items.isEmpty) {
      throw const EmptyCarouselException();
    }

    return LeafletDocument.fromCarouselItems(
      items,
      generatedAt: generatedAt,
    );
  }
}
