import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';

/// Porta de busca/browse coldigom.
abstract interface class ColdigomSearchRepository {
  /// Busca remota + detalhes → grupos para exibição na Home.
  ///
  /// Query vazia → listas vazias (comportamento Home).
  Future<ColdigomSearchResult> search(String query, {int page = 1});

  /// Browse filtrado no servidor (biblioteca); [q] opcional.
  Future<ColdigomBrowseResult> browse(ColdigomBrowseQuery query);
}

/// Parâmetros de browse da biblioteca Coldigom.
class ColdigomBrowseQuery {
  const ColdigomBrowseQuery({
    this.q,
    this.tonalities = const {},
    this.rhythms = const {},
    this.categories = const {},
    this.tagIds = const {},
    this.materialKindIds = const {},
    this.page = 1,
    this.limit = 10,
    this.sortBy = 'numero',
  });

  final String? q;
  final Set<String> tonalities;
  final Set<String> rhythms;
  final Set<String> categories;
  final Set<String> tagIds;
  final Set<String> materialKindIds;
  final int page;
  final int limit;

  /// `numero` | `nome` (UI biblioteca) → API `number` | `name`.
  final String sortBy;

  String get apiSort => sortBy == 'nome' ? 'name' : 'number';
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

/// Resultado de browse da biblioteca com total da API.
class ColdigomBrowseResult {
  const ColdigomBrowseResult({
    required this.groups,
    required this.louvores,
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
  });

  final List<LouvorGroup> groups;
  final List<Louvor> louvores;
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
}
