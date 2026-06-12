import '../../../catalog/domain/entities/louvor_group.dart';

/// Resultado paginado de [LouvorGroup] — UC-03 biblioteca agrupada.
class PaginatedLouvorGroups {
  const PaginatedLouvorGroups({
    required this.items,
    required this.page,
    required this.itemsPerPage,
    required this.totalItems,
    required this.totalPages,
  });

  static const empty = PaginatedLouvorGroups(
    items: [],
    page: 1,
    itemsPerPage: 10,
    totalItems: 0,
    totalPages: 1,
  );

  final List<LouvorGroup> items;
  final int page;
  final int itemsPerPage;
  final int totalItems;
  final int totalPages;
}
