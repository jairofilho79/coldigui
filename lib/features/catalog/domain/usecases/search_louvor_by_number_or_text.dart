import '../entities/louvor.dart';
import '../../../../core/utils/louvor_search_tokens.dart';
import '../search/plpcg_search_index.dart';
import '../utils/louvor_numero_normalizer.dart';

/// UC-01 — Buscar louvor por número ou texto na Home.
///
/// Ranking (alinhado à API coldigom): número exato → título exato →
/// título parcial. Query vazia → `[]`.
class SearchLouvorByNumberOrText {
  const SearchLouvorByNumberOrText();

  /// Busca e ranking sobre um [PlpcgSearchIndex] (número já normalizado uma
  /// vez por manifest via `index.numeroNorm[i]`, não a cada tecla — A10).
  List<Louvor> callIndexed(PlpcgSearchIndex index, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final louvores = index.louvores;
    final numeroNorm = index.numeroNorm;
    final normalizedQuery = LouvorNumeroNormalizer.normalize(trimmed);
    final exactNumber = <Louvor>[];
    for (var i = 0; i < louvores.length; i++) {
      final louvor = louvores[i];
      if (_matchesNumero(
        louvor.numero,
        numeroNorm[i],
        trimmed,
        normalizedQuery,
      )) {
        exactNumber.add(louvor);
      }
    }

    return _rankByTitle(louvores, trimmed, exactNumber);
  }

  /// Completa o ranking: título exato e depois título parcial, sem repetir os
  /// que já entraram por número.
  List<Louvor> _rankByTitle(
    List<Louvor> catalog,
    String trimmed,
    List<Louvor> exactNumber,
  ) {
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

  bool _matchesNumero(
    String louvorNumero,
    String louvorNumeroNorm,
    String query,
    String normalizedQuery,
  ) {
    if (louvorNumero == query) return true;
    if (normalizedQuery.isEmpty) return false;
    return louvorNumeroNorm == normalizedQuery;
  }
}
