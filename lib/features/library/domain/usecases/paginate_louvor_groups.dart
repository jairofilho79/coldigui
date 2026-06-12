import '../../../catalog/domain/entities/louvor_group.dart';
import '../entities/paginated_louvor_groups.dart';
import 'paginate_louvores.dart';

/// UC-03 — Paginar grupos de louvores (mesmas regras de [PaginateLouvores]).
class PaginateLouvorGroups {
  const PaginateLouvorGroups();

  PaginatedLouvorGroups call(
    List<LouvorGroup> groups, {
    required int page,
    required int itemsPerPage,
  }) {
    final perPage = PaginateLouvores.allowedPageSizes.contains(itemsPerPage)
        ? itemsPerPage
        : 10;

    final totalItems = groups.length;
    final totalPages =
        totalItems == 0 ? 1 : (totalItems + perPage - 1) ~/ perPage;
    final safePage = page.clamp(1, totalPages);
    final start = (safePage - 1) * perPage;
    final end = (start + perPage).clamp(0, totalItems);

    return PaginatedLouvorGroups(
      items: start < totalItems ? groups.sublist(start, end) : const [],
      page: safePage,
      itemsPerPage: perPage,
      totalItems: totalItems,
      totalPages: totalPages,
    );
  }
}
