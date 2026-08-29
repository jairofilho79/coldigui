import '../entities/louvor.dart';
import '../../../../core/utils/louvor_search_tokens.dart';
import '../utils/louvor_numero_normalizer.dart';

/// UC-01 — Buscar louvor por número ou texto na Home.
///
/// Ranking (alinhado à API coldigom): número exato → título exato →
/// título parcial. Query vazia → `[]`.
class SearchLouvorByNumberOrText {
  const SearchLouvorByNumberOrText();

  /// Filtra [catalog] pela [query] digitada na Home.
  List<Louvor> call(List<Louvor> catalog, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final exactNumber = catalog
        .where((l) => _matchesNumero(l.numero, trimmed))
        .toList(growable: false);
    final seen = exactNumber.map((l) => l.pdfId).toSet();

    final queryTokens = LouvorSearchTokens.tokenize(trimmed);
    if (queryTokens.isEmpty) return exactNumber;

    final queryNorm = LouvorSearchTokens.normalize(trimmed);
    final queryCompact = LouvorSearchTokens.compact(trimmed);
    final exactTitle = <Louvor>[];
    final partialTitle = <Louvor>[];

    for (final louvor in catalog) {
      if (seen.contains(louvor.pdfId)) continue;
      if (_matchesExactTitle(louvor, queryNorm, queryCompact)) {
        exactTitle.add(louvor);
        seen.add(louvor.pdfId);
        continue;
      }
      final matches = LouvorSearchTokens.matchesText(
        contentTokens: louvor.searchContentTokens,
        compactContent: louvor.searchCompactContent,
        query: trimmed,
        queryTokens: queryTokens,
      );
      if (matches) partialTitle.add(louvor);
    }

    return [...exactNumber, ...exactTitle, ...partialTitle];
  }

  bool _matchesExactTitle(
    Louvor louvor,
    String queryNorm,
    String queryCompact,
  ) {
    if (louvor.searchTitleNorm == queryNorm) return true;
    // pontuação/hífen: "A Ti, Senhor" ≡ "A Ti Senhor"
    return queryCompact.length >= 3 &&
        louvor.searchCompactContent == queryCompact;
  }

  bool _matchesNumero(String louvorNumero, String query) {
    if (louvorNumero == query) return true;
    final normalizedQuery = LouvorNumeroNormalizer.normalize(query);
    if (normalizedQuery.isEmpty) return false;
    return LouvorNumeroNormalizer.normalize(louvorNumero) == normalizedQuery;
  }
}
