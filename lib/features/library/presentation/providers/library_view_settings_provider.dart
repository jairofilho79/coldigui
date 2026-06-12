import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/paginate_louvores.dart';

/// Estado de ordenação e paginação exclusivo da biblioteca UC-03.
class LibraryViewSettings {
  const LibraryViewSettings({
    required this.sortBy,
    required this.itemsPerPage,
    required this.page,
  });

  /// `numero` (padrão) ou `nome` — espelha query `ordenar=`.
  final String sortBy;

  /// Tamanho da página (∈ {10, 25, 50, 100}).
  final int itemsPerPage;

  /// Página atual (1-based).
  final int page;

  factory LibraryViewSettings.defaults() => const LibraryViewSettings(
        sortBy: UrlSyncParams.defaultOrdenar,
        itemsPerPage: 10,
        page: 1,
      );

  LibraryViewSettings copyWith({
    String? sortBy,
    int? itemsPerPage,
    int? page,
  }) {
    return LibraryViewSettings(
      sortBy: sortBy ?? this.sortBy,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      page: page ?? this.page,
    );
  }

  /// Valores serializáveis para URL (omitir quando padrão).
  String? get ordenarUrlValue =>
      sortBy == UrlSyncParams.defaultOrdenar ? null : sortBy;

  String? get itensPorPaginaUrlValue =>
      itemsPerPage == 10 ? null : itemsPerPage.toString();

  String? get paginaUrlValue => page == 1 ? null : page.toString();
}

/// Ordenação e paginação da biblioteca — UC-03.
final libraryViewSettingsProvider =
    NotifierProvider<LibraryViewSettingsNotifier, LibraryViewSettings>(
  LibraryViewSettingsNotifier.new,
);

/// Gerencia `ordenar`, `itensPorPagina` e `pagina` com hidratação da URL.
class LibraryViewSettingsNotifier extends Notifier<LibraryViewSettings> {
  @override
  LibraryViewSettings build() => LibraryViewSettings.defaults();

  /// Hidrata view settings a partir de query params da rota Biblioteca.
  void hydrateFromUrl({
    String? ordenar,
    String? itensPorPagina,
    String? pagina,
  }) {
    final parsedSort =
        ordenar == 'nome' ? 'nome' : UrlSyncParams.defaultOrdenar;
    final parsedPageSize = int.tryParse(itensPorPagina ?? '') ?? 10;
    final normalizedPageSize =
        PaginateLouvores.allowedPageSizes.contains(parsedPageSize)
            ? parsedPageSize
            : 10;
    final parsedPage = int.tryParse(pagina ?? '') ?? 1;

    state = LibraryViewSettings(
      sortBy: parsedSort,
      itemsPerPage: normalizedPageSize,
      page: parsedPage < 1 ? 1 : parsedPage,
    );
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  /// Altera tamanho da página e reseta para página 1.
  void setItemsPerPage(int itemsPerPage) {
    final normalized = PaginateLouvores.allowedPageSizes.contains(itemsPerPage)
        ? itemsPerPage
        : 10;
    state = state.copyWith(itemsPerPage: normalized, page: 1);
  }

  void setPage(int page) {
    state = state.copyWith(page: page < 1 ? 1 : page);
  }

  void goToNextPage(int totalPages) {
    if (state.page >= totalPages) return;
    state = state.copyWith(page: state.page + 1);
  }

  void goToPreviousPage() {
    if (state.page <= 1) return;
    state = state.copyWith(page: state.page - 1);
  }
}
