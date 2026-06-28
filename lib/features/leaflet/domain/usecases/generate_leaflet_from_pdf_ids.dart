import '../../../carousel/domain/entities/carousel_item.dart';
import '../../../playlists/domain/exceptions/empty_carousel_exception.dart';
import '../entities/leaflet_document.dart';

/// UC-08 — Folheto a partir de IDs ordenados (playlist salva, sem carousel).
class GenerateLeafletFromPdfIds {
  const GenerateLeafletFromPdfIds();

  /// Lança [EmptyCarouselException] se [pdfIds] vazio.
  LeafletDocument call({
    required List<String> pdfIds,
    Map<String, CarouselItemMetadata>? pdfIdToMetadata,
    DateTime? generatedAt,
  }) {
    if (pdfIds.isEmpty) {
      throw const EmptyCarouselException();
    }

    return LeafletDocument.fromPdfIds(
      pdfIds,
      pdfIdToMetadata: pdfIdToMetadata ?? const {},
      generatedAt: generatedAt,
    );
  }
}
