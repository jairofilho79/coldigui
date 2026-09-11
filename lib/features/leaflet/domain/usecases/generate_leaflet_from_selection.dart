import '../../../playlists/domain/exceptions/empty_carousel_exception.dart';
import '../entities/leaflet_document.dart';

/// UC-08 — Gerar folheto da seleção atual (Fase 4.6).
///
/// A seleção deixou de ter repositório próprio (D3): os ids da face de
/// partituras da lista ativa chegam por [readSelectionIds], injetado pelo
/// provider. Lança [EmptyCarouselException] se a seleção estiver vazia.
class GenerateLeafletFromSelection {
  const GenerateLeafletFromSelection(this._readSelectionIds);

  final Future<List<String>> Function() _readSelectionIds;

  /// Retorna documento com número/nome por louvor para captura/impressão.
  ///
  /// [labelOf] rotula os ids; sem ele, o id vira o nome.
  Future<LeafletDocument> call({
    LeafletLabelOf? labelOf,
    DateTime? generatedAt,
  }) async {
    final ids = await _readSelectionIds();
    if (ids.isEmpty) {
      throw const EmptyCarouselException();
    }

    return LeafletDocument.fromPdfIds(
      ids,
      labelOf: labelOf ?? _noLabel,
      generatedAt: generatedAt,
    );
  }
}

LeafletLabel? _noLabel(String _) => null;
