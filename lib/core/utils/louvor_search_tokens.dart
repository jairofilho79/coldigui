/// Busca tolerante — stop words PT e normalização de tokens (UC-01).
abstract final class LouvorSearchTokens {
  /// ~40 stop words funcionais em português removidas na tokenização.
  static const Set<String> stopWords = {
    'a',
    'o',
    'e',
    'de',
    'da',
    'do',
    'em',
    'um',
    'uma',
    'os',
    'as',
    'dos',
    'das',
    'que',
    'no',
    'na',
    'nos',
    'nas',
    'por',
    'para',
    'com',
    'sem',
    'ao',
    'aos',
    'à',
    'às',
    'se',
    'ou',
    'mas',
    'como',
    'mais',
    'muito',
    'já',
    'é',
    'são',
  };

  /// Remove acentos e converte para minúsculas.
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');
  }

  /// Tokeniza título removendo stop words.
  static List<String> tokenize(String title) {
    return normalize(title)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !stopWords.contains(t))
        .toList();
  }
}
