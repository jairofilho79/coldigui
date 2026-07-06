import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';

/// Porta de busca coldigom para a Home (fase 1).
abstract interface class ColdigomSearchRepository {
  /// Busca remota + detalhes → grupos para exibição na Home.
  Future<ColdigomSearchResult> search(String query);
}

/// Resultado da busca coldigom com louvores flat para cache.
class ColdigomSearchResult {
  const ColdigomSearchResult({required this.groups, required this.louvores});

  final List<LouvorGroup> groups;
  final List<Louvor> louvores;
}
