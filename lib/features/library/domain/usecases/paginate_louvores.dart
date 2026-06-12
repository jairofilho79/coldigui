import '../entities/paginated_louvores.dart';
import '../../../catalog/domain/entities/louvor.dart';

/// UC-03 — Paginar louvores (Fase 1.4).
///
/// Fatia a lista conforme [UrlSyncParams.itensPorPagina] (10/25/50/100)
/// e [UrlSyncParams.pagina].
class PaginateLouvores {
  const PaginateLouvores();

  /// Tamanhos de página permitidos.
  static const Set<int> allowedPageSizes = {10, 25, 50, 100};

  /// [page] é 1-based; [itemsPerPage] inválido → `10`.
  PaginatedLouvores call(
    List<Louvor> louvores, {
    required int page,
    required int itemsPerPage,
  }) {
    final normalizedPageSize =
        allowedPageSizes.contains(itemsPerPage) ? itemsPerPage : 10;
    final totalItems = louvores.length;
    final totalPages =
        totalItems == 0 ? 1 : (totalItems / normalizedPageSize).ceil();
    final clampedPage = page.clamp(1, totalPages);
    final start = (clampedPage - 1) * normalizedPageSize;
    final end = (start + normalizedPageSize).clamp(0, totalItems);
    final items =
        start < totalItems ? louvores.sublist(start, end) : const <Louvor>[];

    return PaginatedLouvores(
      items: items,
      page: clampedPage,
      itemsPerPage: normalizedPageSize,
      totalItems: totalItems,
      totalPages: totalPages,
    );
  }
}
