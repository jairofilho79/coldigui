import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';

/// Porta de busca coldigom para a Home (fase 1).
abstract interface class ColdigomSearchRepository {
  /// Busca remota + detalhes → grupos para exibição na Home.
  ///
  /// [page] é 1-based. [hasNextPage] no resultado usa heurística
  /// `summaries.length >= limit` (API sem meta de total).
  Future<ColdigomSearchResult> search(String query, {int page = 1});
}

/// Resultado da busca coldigom com louvores flat para cache.
class ColdigomSearchResult {
  const ColdigomSearchResult({
    required this.groups,
    required this.louvores,
    this.page = 1,
    this.hasNextPage = false,
  });

  final List<LouvorGroup> groups;
  final List<Louvor> louvores;
  final int page;
  final bool hasNextPage;
}
