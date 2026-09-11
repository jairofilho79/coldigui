import 'dart:async';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
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

  LibraryViewSettings copyWith({String? sortBy, int? itemsPerPage, int? page}) {
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

/// Gerencia `ordenar`, `itensPorPagina` e `pagina` com persistência (C13) e
/// hidratação da URL.
class LibraryViewSettingsNotifier extends Notifier<LibraryViewSettings> {
  /// `true` quando `itemsPerPage` já veio de um valor explícito (gravado em
  /// [build] ou de `itensPorPagina` na URL) — [setDefaultForWidth] só age
  /// enquanto isto for `false`.
  bool _hasExplicitItemsPerPage = false;

  @override
  LibraryViewSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getInt(StorageKeys.libraryItemsPerPage);
    if (stored != null && PaginateLouvores.allowedPageSizes.contains(stored)) {
      _hasExplicitItemsPerPage = true;
      return LibraryViewSettings.defaults().copyWith(itemsPerPage: stored);
    }
    return LibraryViewSettings.defaults();
  }

  /// Hidrata view settings a partir de query params da rota Biblioteca.
  void hydrateFromUrl({
    String? ordenar,
    String? itensPorPagina,
    String? pagina,
  }) {
    final parsedSort = ordenar == 'nome'
        ? 'nome'
        : UrlSyncParams.defaultOrdenar;
    final hasPageSize =
        itensPorPagina != null && itensPorPagina.trim().isNotEmpty;
    final parsedPageSize = int.tryParse(itensPorPagina ?? '') ?? 10;
    final normalizedPageSize =
        PaginateLouvores.allowedPageSizes.contains(parsedPageSize)
        ? parsedPageSize
        : 10;
    final parsedPage = int.tryParse(pagina ?? '') ?? 1;

    if (hasPageSize) _hasExplicitItemsPerPage = true;

    state = LibraryViewSettings(
      sortBy: parsedSort,
      itemsPerPage: hasPageSize ? normalizedPageSize : state.itemsPerPage,
      page: parsedPage < 1 ? 1 : parsedPage,
    );
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  /// Altera tamanho da página, persiste e reseta para página 1.
  void setItemsPerPage(int itemsPerPage) {
    final normalized = PaginateLouvores.allowedPageSizes.contains(itemsPerPage)
        ? itemsPerPage
        : 10;
    _hasExplicitItemsPerPage = true;
    state = state.copyWith(itemsPerPage: normalized, page: 1);
    final prefs = ref.read(sharedPreferencesProvider);
    unawaited(prefs.setInt(StorageKeys.libraryItemsPerPage, normalized));
  }

  /// Escolhe o tamanho de página padrão pela largura da tela (C13) — chamado
  /// uma vez pela [LibraryScreen] no primeiro build. Só age quando não há
  /// valor gravado nem `itensPorPagina` na URL; caso contrário é no-op.
  void setDefaultForWidth(double width) {
    if (_hasExplicitItemsPerPage) return;
    _hasExplicitItemsPerPage = true;
    // kWideLayoutBreakpoint (Tarefa 5)
    final defaultSize = width >= 900 ? 25 : 10;
    state = state.copyWith(itemsPerPage: defaultSize);
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
