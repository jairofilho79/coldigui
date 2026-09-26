import '../../../catalog/domain/entities/catalog_list_entry.dart';
import '../entities/paginated_catalog_entries.dart';
import 'paginate_louvores.dart';

/// UC-03 — Paginar as entradas da /biblioteca (mesmas regras de
/// [PaginateLouvores]); o amendoim conta como um item.
class PaginateCatalogEntries {
  const PaginateCatalogEntries();

  PaginatedCatalogEntries call(
    List<CatalogListEntry> entries, {
    required int page,
    required int itemsPerPage,
  }) {
    final perPage = PaginateLouvores.allowedPageSizes.contains(itemsPerPage)
        ? itemsPerPage
        : 10;

    final totalItems = entries.length;
    final totalPages =
        totalItems == 0 ? 1 : (totalItems + perPage - 1) ~/ perPage;
    final safePage = page.clamp(1, totalPages);
    final start = (safePage - 1) * perPage;
    final end = (start + perPage).clamp(0, totalItems);

    return PaginatedCatalogEntries(
      items: start < totalItems ? entries.sublist(start, end) : const [],
      page: safePage,
      itemsPerPage: perPage,
      totalItems: totalItems,
      totalPages: totalPages,
    );
  }
}
