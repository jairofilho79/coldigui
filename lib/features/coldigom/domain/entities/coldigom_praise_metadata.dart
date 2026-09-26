/// Metadados de um praise Coldigom para o sheet de materiais e para o
/// trecho da letra no card de resultado de busca (C5.1).
class ColdigomPraiseMetadata {
  const ColdigomPraiseMetadata({
    required this.name,
    this.tonality = '',
    this.author = '',
    this.rhythm = '',
    this.tagNames = const [],
    this.lyricsExcerpt,
    this.shortId,
    this.groupId,
  });

  final String name;
  final String tonality;
  final String author;
  final String rhythm;
  final List<String> tagNames;

  /// Trecho da letra ao redor do match da busca — `null` fora de uma busca
  /// que bateu na letra.
  final String? lyricsExcerpt;

  /// `shortId` do praise — chave do link por louvor (`?p=`, plano 2) e do
  /// mapa `ColdigomSearchIndex.groupByShortId`. `null` quando o coldigom
  /// ainda não o expõe para este praise.
  final String? shortId;

  /// `group_id` do praise no coldigom (chave opaca do grupo de versões) — é
  /// por ele que a lista junta as versões num amendoim (spec
  /// louvores-agrupados §4). `null` fora de grupo.
  ///
  /// **Não** confundir com `LouvorGroup.groupId`: apesar do nome, aquele é o
  /// id do próprio praise (um card por praise), não o grupo do coldigom.
  final String? groupId;

  /// Há algo a mostrar no bloco de metadados da ficha. A seção da Coletânea
  /// vem em [tagNames] (spec seções-coletânea §4.1).
  bool get hasAnyField =>
      tonality.trim().isNotEmpty ||
      author.trim().isNotEmpty ||
      rhythm.trim().isNotEmpty ||
      tagNames.isNotEmpty;
}
