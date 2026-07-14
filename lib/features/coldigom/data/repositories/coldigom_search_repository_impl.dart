import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../adapters/coldigom_louvor_adapter.dart';
import '../datasources/coldigom_remote_datasource.dart';
import '../../domain/repositories/coldigom_search_repository.dart';

/// Orquestra busca coldigom: resumo → detalhes paralelos → adapter → grupos.
class ColdigomSearchRepositoryImpl implements ColdigomSearchRepository {
  const ColdigomSearchRepositoryImpl(
    this._remote, {
    this.searchLimit = 20,
    this.detailConcurrency = 5,
  });

  final ColdigomRemoteDatasource _remote;
  final int searchLimit;
  final int detailConcurrency;

  @override
  Future<ColdigomSearchResult> search(String query, {int page = 1}) async {
    final trimmed = query.trim();
    final safePage = page < 1 ? 1 : page;
    if (trimmed.isEmpty) {
      return ColdigomSearchResult(
        groups: const [],
        louvores: const [],
        page: safePage,
      );
    }

    final summaries = await _remote.search(
      query: trimmed,
      limit: searchLimit,
      page: safePage,
    );
    if (summaries.isEmpty) {
      return ColdigomSearchResult(
        groups: const [],
        louvores: const [],
        page: safePage,
      );
    }

    final louvores = <Louvor>[];
    for (var i = 0; i < summaries.length; i += detailConcurrency) {
      final batch = summaries.skip(i).take(detailConcurrency);
      final details = await Future.wait(
        batch.map((s) => _remote.fetchDetail(s.id)),
      );
      for (final detail in details) {
        louvores.addAll(ColdigomLouvorAdapter.toLouvores(detail));
      }
    }

    final groups = LouvorGroup.fromLouvores(louvores);
    return ColdigomSearchResult(
      groups: groups,
      louvores: louvores,
      page: safePage,
      hasNextPage: summaries.length >= searchLimit,
    );
  }
}
