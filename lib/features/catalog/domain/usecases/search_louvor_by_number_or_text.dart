import '../entities/louvor.dart';
import '../../../../core/utils/louvor_search_tokens.dart';
import '../utils/louvor_numero_normalizer.dart';

/// UC-01 — Buscar louvor por número ou texto na Home.
///
/// Filtro in-memory sobre o manifest: query vazia → `[]`; número exato
/// prioritário ([LouvorNumeroNormalizer] — `3` ≡ `003`); texto tolerante via
/// [LouvorSearchTokens.matchesText].
class SearchLouvorByNumberOrText {
  const SearchLouvorByNumberOrText();

  /// Filtra [catalog] pela [query] digitada na Home.
  List<Louvor> call(List<Louvor> catalog, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final exactMatches = catalog
        .where((l) => _matchesNumero(l.numero, trimmed))
        .toList(growable: false);
    final exactIds = exactMatches.map((l) => l.pdfId).toSet();

    final queryTokens = LouvorSearchTokens.tokenize(trimmed);
    if (queryTokens.isEmpty) return exactMatches;

    final textMatches = <Louvor>[];
    for (final louvor in catalog) {
      if (exactIds.contains(louvor.pdfId)) continue;
      final matches = LouvorSearchTokens.matchesText(
        contentTokens: louvor.searchContentTokens,
        compactContent: louvor.searchCompactContent,
        query: trimmed,
        queryTokens: queryTokens,
      );
      if (matches) textMatches.add(louvor);
    }

    return [...exactMatches, ...textMatches];
  }

  bool _matchesNumero(String louvorNumero, String query) {
    if (louvorNumero == query) return true;
    final normalizedQuery = LouvorNumeroNormalizer.normalize(query);
    if (normalizedQuery.isEmpty) return false;
    return LouvorNumeroNormalizer.normalize(louvorNumero) == normalizedQuery;
  }
}
