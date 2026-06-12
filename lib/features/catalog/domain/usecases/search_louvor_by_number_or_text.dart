import '../entities/louvor.dart';
import '../../../../core/utils/louvor_search_tokens.dart';

/// UC-01 — Buscar louvor por número ou texto na Home.
///
/// Filtro in-memory sobre o manifest: query vazia → `[]`; número exato
/// prioritário; texto tolerante via tokens pré-computados em [Louvor].
class SearchLouvorByNumberOrText {
  const SearchLouvorByNumberOrText();

  /// Filtra [catalog] pela [query] digitada na Home.
  List<Louvor> call(List<Louvor> catalog, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final exactMatches =
        catalog.where((l) => l.numero == trimmed).toList(growable: false);
    final exactIds = exactMatches.map((l) => l.pdfId).toSet();

    final queryTokens = LouvorSearchTokens.tokenize(trimmed);
    if (queryTokens.isEmpty) return exactMatches;

    final textMatches = <Louvor>[];
    for (final louvor in catalog) {
      if (exactIds.contains(louvor.pdfId)) continue;
      final matchesAll =
          queryTokens.every((t) => louvor.searchContentTokens.contains(t));
      if (matchesAll) textMatches.add(louvor);
    }

    return [...exactMatches, ...textMatches];
  }
}
