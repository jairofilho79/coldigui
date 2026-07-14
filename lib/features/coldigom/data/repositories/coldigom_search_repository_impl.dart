import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../domain/repositories/coldigom_search_repository.dart';
import '../adapters/coldigom_louvor_adapter.dart';
import '../datasources/coldigom_remote_datasource.dart';
import '../models/praise_dto.dart';

/// Orquestra busca/browse coldigom: resumo → detalhes paralelos → adapter → grupos.
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

    final pageDto = await _remote.listPraises(
      ColdigomPraisesQuery(q: trimmed, limit: searchLimit, page: safePage),
    );
    if (pageDto.data.isEmpty) {
      return ColdigomSearchResult(
        groups: const [],
        louvores: const [],
        page: safePage,
      );
    }

    final louvores = await _fetchLouvoresForSummaries(pageDto.data);
    final groups = LouvorGroup.fromLouvores(louvores);
    return ColdigomSearchResult(
      groups: groups,
      louvores: louvores,
      page: safePage,
      hasNextPage: pageDto.data.length >= searchLimit,
    );
  }

  @override
  Future<ColdigomBrowseResult> browse(ColdigomBrowseQuery query) async {
    final safePage = query.page < 1 ? 1 : query.page;
    final safeLimit = query.limit < 1 ? 10 : query.limit;

    final pageDto = await _remote.listPraises(
      ColdigomPraisesQuery(
        q: query.q,
        tonalities: query.tonalities,
        rhythms: query.rhythms,
        categories: query.categories,
        tagIds: query.tagIds,
        materialKindIds: query.materialKindIds,
        page: safePage,
        limit: safeLimit,
        sort: query.apiSort,
      ),
    );

    final totalPages = pageDto.pagination.totalPages < 1
        ? 1
        : pageDto.pagination.totalPages;

    if (pageDto.data.isEmpty) {
      return ColdigomBrowseResult(
        groups: const [],
        louvores: const [],
        page: pageDto.pagination.page,
        limit: pageDto.pagination.limit,
        totalItems: pageDto.pagination.total,
        totalPages: totalPages,
      );
    }

    final louvores = await _fetchLouvoresForSummaries(pageDto.data);
    final groups = LouvorGroup.fromLouvores(louvores);

    return ColdigomBrowseResult(
      groups: groups,
      louvores: louvores,
      page: pageDto.pagination.page,
      limit: pageDto.pagination.limit,
      totalItems: pageDto.pagination.total,
      totalPages: totalPages,
    );
  }

  Future<List<Louvor>> _fetchLouvoresForSummaries(
    List<PraiseSummaryDto> summaries,
  ) async {
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
    return louvores;
  }
}
