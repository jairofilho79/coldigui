import '../../../catalog/domain/entities/louvor.dart';

/// Resultado paginado da biblioteca UC-03.
class PaginatedLouvores {
  const PaginatedLouvores({
    required this.items,
    required this.page,
    required this.itemsPerPage,
    required this.totalItems,
    required this.totalPages,
  });

  /// Louvores da página atual.
  final List<Louvor> items;

  /// Página atual (1-based, já clamped).
  final int page;

  /// Tamanho da página (∈ {10, 25, 50, 100}).
  final int itemsPerPage;

  /// Total de itens após filtros e ordenação.
  final int totalItems;

  /// Total de páginas (mínimo 1).
  final int totalPages;

  /// Estado vazio para loading/erro do manifest.
  static const empty = PaginatedLouvores(
    items: [],
    page: 1,
    itemsPerPage: 10,
    totalItems: 0,
    totalPages: 1,
  );
}
