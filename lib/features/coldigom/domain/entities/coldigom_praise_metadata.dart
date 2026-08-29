/// Metadados de um praise Coldigom para o sheet de materiais.
class ColdigomPraiseMetadata {
  const ColdigomPraiseMetadata({
    required this.name,
    this.tonality = '',
    this.author = '',
    this.rhythm = '',
    this.category = '',
    this.tagNames = const [],
  });

  final String name;
  final String tonality;
  final String author;
  final String rhythm;
  final String category;
  final List<String> tagNames;

  bool get hasAnyField =>
      tonality.trim().isNotEmpty ||
      author.trim().isNotEmpty ||
      rhythm.trim().isNotEmpty ||
      category.trim().isNotEmpty ||
      tagNames.isNotEmpty;
}
