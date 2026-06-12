import '../../../carousel/domain/entities/carousel_item.dart';
import 'leaflet_entry.dart';

/// Documento de folheto pronto para renderização (UC-08).
class LeafletDocument {
  const LeafletDocument({
    required this.entries,
    required this.generatedAt,
  });

  /// Linhas na ordem da seleção.
  final List<LeafletEntry> entries;

  /// Data/hora de geração — exibida no cabeçalho do folheto.
  final DateTime generatedAt;

  /// Monta folheto a partir dos itens do carousel, preservando [CarouselItem.sortOrder].
  ///
  /// Índices [LeafletEntry.index] são 1-based. [generatedAt] default: `DateTime.now()`.
  factory LeafletDocument.fromCarouselItems(
    List<CarouselItem> items, {
    DateTime? generatedAt,
  }) {
    final sorted = List<CarouselItem>.from(items)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return LeafletDocument(
      generatedAt: generatedAt ?? DateTime.now(),
      entries: [
        for (var i = 0; i < sorted.length; i++)
          LeafletEntry(
            index: i + 1,
            numero: sorted[i].numero,
            nome: sorted[i].nome,
          ),
      ],
    );
  }
}
