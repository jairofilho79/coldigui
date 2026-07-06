import '../../../catalog/domain/entities/louvor_data_source.dart';

/// Item do carousel enriquecido para UI (UC-05, Fase 4.1).
///
/// Persistência usa apenas [pdfId] e [sortOrder]; demais campos são derivados
/// do manifest em [carouselLouvoresProvider].
class CarouselItem {
  const CarouselItem({
    required this.pdfId,
    required this.sortOrder,
    required this.numero,
    required this.nome,
    required this.categoria,
    required this.classificacao,
    this.source = LouvorDataSource.plpcg,
  });

  /// Identificador estável do louvor (Base64 URL-safe do path PDF).
  final String pdfId;

  /// Posição na seleção — contíguo 0..n-1 após compactação.
  final int sortOrder;

  /// Número do louvor (manifest `numero`).
  final String numero;

  /// Título do louvor (manifest `nome`).
  final String nome;

  /// Material: Partitura, Cifra, Gestos em Gravura, etc.
  final String categoria;

  /// Classificação normalizada (ex.: ColAdultos).
  final String classificacao;

  /// Origem dos metadados — define cor do chip na UI.
  final LouvorDataSource source;

  /// Rótulo legado — tipicamente `numero — nome` (folheto UC-08).
  String get label => numero.isEmpty ? nome : '$numero — $nome';
}

/// Metadados de louvor para enriquecer chips sem acoplar ao catálogo.
///
/// Mapa `pdfId → CarouselItemMetadata` alimenta
/// [CarouselRepository.getOrderedItems] a partir do manifest.
class CarouselItemMetadata {
  const CarouselItemMetadata({
    required this.numero,
    required this.nome,
    required this.categoria,
    required this.classificacao,
    this.source = LouvorDataSource.plpcg,
  });

  final String numero;
  final String nome;
  final String categoria;
  final String classificacao;
  final LouvorDataSource source;
}
