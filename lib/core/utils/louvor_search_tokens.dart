/// Busca tolerante UC-01 — normalização, tokenização e match flexível.
///
/// Suporta acentos, stop words PT, hífens/pontuação como separadores e
/// queries compactas sem separadores (ex.: `buscarmeeis` → `Buscar-me-eis`).
abstract final class LouvorSearchTokens {
  /// Mínimo de caracteres para match compacto sem separadores (ex.: buscarmeeis).
  static const int _minCompactQueryLength = 3;

  static final RegExp _regA = RegExp(r'[àáâãäå]');
  static final RegExp _regE = RegExp(r'[èéêë]');
  static final RegExp _regI = RegExp(r'[ìíîï]');
  static final RegExp _regO = RegExp(r'[òóôõö]');
  static final RegExp _regU = RegExp(r'[ùúûü]');
  static final RegExp _nonAlphanumeric = RegExp(r'[^a-z0-9]');
  static final RegExp _nonAlphanumericPlus = RegExp(r'[^a-z0-9]+');

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
        .replaceAll(_regA, 'a')
        .replaceAll(_regE, 'e')
        .replaceAll(_regI, 'i')
        .replaceAll(_regO, 'o')
        .replaceAll(_regU, 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');
  }

  /// Remove separadores e pontuação — ex.: "Buscar-me-eis" → "buscarmeeis".
  static String compact(String text) {
    return normalize(text).replaceAll(_nonAlphanumeric, '');
  }

  /// Indica se a query usa separadores (espaço, hífen, pontuação, etc.).
  static bool hasWordSeparators(String text) {
    return _nonAlphanumeric.hasMatch(normalize(text));
  }

  /// Tokeniza título removendo stop words e separadores (hífen, pontuação).
  static List<String> tokenize(String title) {
    return normalize(title)
        .split(_nonAlphanumericPlus)
        .where((t) => t.isNotEmpty && !stopWords.contains(t))
        .toList();
  }

  /// Verifica match textual UC-01.
  ///
  /// 1. **Tokens** — todos os [queryTokens] presentes em [contentTokens]
  ///    (ex.: `buscar me eis`, `buscar-me-eis`).
  /// 2. **Compacto** — se [query] não tem separadores e tem ≥3 caracteres,
  ///    [compact](query) é substring de [compactContent]
  ///    (ex.: `buscarmeeis`).
  static bool matchesText({
    required List<String> contentTokens,
    required String compactContent,
    required String query,
    required List<String> queryTokens,
  }) {
    final tokenMatch =
        queryTokens.every((token) => contentTokens.contains(token));
    if (tokenMatch) return true;

    if (hasWordSeparators(query)) return false;

    final compactQuery = compact(query);
    if (compactQuery.length < _minCompactQueryLength) return false;

    return compactContent.contains(compactQuery);
  }
}
