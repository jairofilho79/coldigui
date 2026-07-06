import '../../../catalog/domain/entities/louvor.dart';
import '../../domain/entities/carousel_item.dart';

/// Metadados de chips a partir do manifest PLPCG + cache coldigom.
Map<String, CarouselItemMetadata> buildCarouselMetadataMap({
  List<Louvor>? plpcgCatalog,
  Map<String, Louvor>? coldigomCache,
}) {
  final map = <String, CarouselItemMetadata>{};

  if (plpcgCatalog != null) {
    for (final louvor in plpcgCatalog) {
      map[louvor.pdfId] = CarouselItemMetadata(
        numero: louvor.numero,
        nome: louvor.nome,
        categoria: louvor.categoria,
        classificacao: louvor.classificacao,
        source: louvor.source,
      );
    }
  }

  if (coldigomCache != null) {
    for (final louvor in coldigomCache.values) {
      map[louvor.pdfId] = CarouselItemMetadata(
        numero: louvor.numero,
        nome: louvor.nome,
        categoria: louvor.categoria,
        classificacao: louvor.classificacao,
        source: louvor.source,
      );
    }
  }

  return map;
}
