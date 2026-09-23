/// Metadados de um praise Coldigom para o sheet de materiais e para o
/// trecho da letra no card de resultado de busca (C5.1).
class ColdigomPraiseMetadata {
  const ColdigomPraiseMetadata({
    required this.name,
    this.tonality = '',
    this.author = '',
    this.rhythm = '',
    this.category = '',
    this.tagNames = const [],
    this.lyricsExcerpt,
    this.shortId,
  });

  final String name;
  final String tonality;
  final String author;
  final String rhythm;
  final String category;
  final List<String> tagNames;

  /// Trecho da letra ao redor do match da busca — `null` fora de uma busca
  /// que bateu na letra.
  final String? lyricsExcerpt;

  /// `shortId` do praise — chave do link por louvor (`?p=`, plano 2) e do
  /// mapa `ColdigomSearchIndex.groupByShortId`. `null` quando o coldigom
  /// ainda não o expõe para este praise.
  final String? shortId;

  bool get hasAnyField =>
      tonality.trim().isNotEmpty ||
      author.trim().isNotEmpty ||
      rhythm.trim().isNotEmpty ||
      category.trim().isNotEmpty ||
      tagNames.isNotEmpty;
}
