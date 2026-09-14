import '../../../carousel/domain/entities/carousel_item.dart';
import 'leaflet_entry.dart';

/// Rótulo de um material no folheto — [numero] pode ser vazio.
typedef LeafletLabel = ({String numero, String nome});

/// Resolve o rótulo de um id; `null` quando o material não está em memória.
///
/// O folheto não conhece catálogo nem caches: quem chama passa o resolvedor
/// (na app, o `CatalogMaterialLookup`; nos testes, um mapa).
typedef LeafletLabelOf = LeafletLabel? Function(String materialId);

/// Documento de folheto pronto para renderização (UC-08).
class LeafletDocument {
  const LeafletDocument({
    required this.entries,
    required this.generatedAt,
    this.shareUrl,
  });

  /// Linhas na ordem da seleção.
  final List<LeafletEntry> entries;

  /// Data/hora de geração — exibida no cabeçalho do folheto.
  final DateTime generatedAt;

  /// Link curto da lista para o QR do rodapé (spec short-id-share D10).
  /// `null` = sem QR (link longo, ou folheto sem lista salva).
  final String? shareUrl;

  /// Monta folheto a partir dos itens do carousel, preservando
  /// [CarouselItem.index] (a posição dentro da face).
  ///
  /// Índices [LeafletEntry.index] são 1-based. [generatedAt] default: `DateTime.now()`.
  factory LeafletDocument.fromCarouselItems(
    List<CarouselItem> items, {
    DateTime? generatedAt,
    String? shareUrl,
  }) {
    final sorted = List<CarouselItem>.from(items)
      ..sort((a, b) => a.index.compareTo(b.index));

    return LeafletDocument(
      generatedAt: generatedAt ?? DateTime.now(),
      shareUrl: shareUrl,
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

  /// Monta folheto a partir de [pdfIds] ordenados, rotulados por [labelOf].
  ///
  /// Id sem rótulo entra com número vazio e o próprio id como nome.
  factory LeafletDocument.fromPdfIds(
    List<String> pdfIds, {
    required LeafletLabelOf labelOf,
    DateTime? generatedAt,
    String? shareUrl,
  }) {
    return LeafletDocument(
      generatedAt: generatedAt ?? DateTime.now(),
      shareUrl: shareUrl,
      entries: [
        for (final (i, id) in pdfIds.indexed)
          switch (labelOf(id)) {
            final label? => LeafletEntry(
              index: i + 1,
              numero: label.numero,
              nome: label.nome,
            ),
            null => LeafletEntry(index: i + 1, numero: '', nome: id),
          },
      ],
    );
  }
}
