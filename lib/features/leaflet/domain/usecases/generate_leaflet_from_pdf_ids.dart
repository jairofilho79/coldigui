import '../../../playlists/domain/exceptions/empty_carousel_exception.dart';
import '../entities/leaflet_document.dart';

/// UC-08 — Folheto a partir de IDs ordenados (playlist salva, sem carousel).
class GenerateLeafletFromPdfIds {
  const GenerateLeafletFromPdfIds();

  /// Lança [EmptyCarouselException] se [pdfIds] vazio.
  ///
  /// [labelOf] rotula os ids; sem ele, o id vira o nome.
  LeafletDocument call({
    required List<String> pdfIds,
    LeafletLabelOf? labelOf,
    DateTime? generatedAt,
  }) {
    if (pdfIds.isEmpty) {
      throw const EmptyCarouselException();
    }

    return LeafletDocument.fromPdfIds(
      pdfIds,
      labelOf: labelOf ?? _noLabel,
      generatedAt: generatedAt,
    );
  }
}

LeafletLabel? _noLabel(String _) => null;
