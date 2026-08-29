import '../../../catalog/domain/entities/louvor.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../domain/entities/carousel_item.dart';

/// Metadados de chips a partir do manifest PLPCG + cache coldigom + cache de cifras.
Map<String, CarouselItemMetadata> buildCarouselMetadataMap({
  List<Louvor>? plpcgCatalog,
  Map<String, Louvor>? coldigomCache,
  Map<String, ChordMaterial>? chordCache,
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

  if (chordCache != null) {
    for (final chord in chordCache.values) {
      map[chord.chordId] = CarouselItemMetadata(
        numero: chord.numero,
        nome: chord.nome,
        categoria: chord.categoria,
        classificacao: chord.classificacao,
        source: chord.source,
      );
    }
  }

  return map;
}
