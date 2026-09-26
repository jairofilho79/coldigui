import '../../../catalog/domain/entities/catalog_list_entry.dart';

/// Página da /biblioteca — em **cartões** (`CatalogListEntry`): um amendoim
/// conta 1 e nunca se parte entre páginas (spec louvores-agrupados §4.3).
class PaginatedCatalogEntries {
  const PaginatedCatalogEntries({
    required this.items,
    required this.page,
    required this.itemsPerPage,
    required this.totalItems,
    required this.totalPages,
  });

  static const empty = PaginatedCatalogEntries(
    items: [],
    page: 1,
    itemsPerPage: 10,
    totalItems: 0,
    totalPages: 1,
  );

  final List<CatalogListEntry> items;
  final int page;
  final int itemsPerPage;
  final int totalItems;
  final int totalPages;
}
