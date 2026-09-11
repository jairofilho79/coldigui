import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/plpcg_catalog_source_provider.dart';
import '../../domain/entities/catalog_query.dart';
import '../../domain/entities/louvor_group.dart';
import 'catalog_filters_provider.dart';
import 'home_remote_search_provider.dart';
import 'home_search_state.dart';

/// Estado da busca e filtros na Home (UC-01 + UC-02).
///
/// Pipeline declarativo (C.2):
/// ```
/// homeSearchQueryProvider (texto cru)
///   → homeSearchDebouncedQueryProvider (300 ms)
///       ├→ homeLocalSearchProvider   (índice PLPCG, síncrono, + filtros)
///       └→ homeRemoteSearchProvider((query, página))  (Coldigom, cancelável)
///             → homeSearchStateProvider → HomeSearchResultsSliver
/// ```
/// Sync URL: [homeSearchUrlSyncQueryProvider] + [catalogFiltersProvider]
/// consumidos por `HomeScreen` → `buildHomeLocation`.
///
/// Texto imediato digitado na `SearchBar` (sem debounce).
final homeSearchQueryProvider = NotifierProvider<HomeSearchQuery, String>(
  HomeSearchQuery.new,
);

/// Query debounced 300 ms — dispara a busca local e a chave remota.
final homeSearchDebouncedQueryProvider =
    NotifierProvider<HomeSearchDebouncer, String>(HomeSearchDebouncer.new);

/// Página 1-based da busca remota; volta a 1 quando a query ou os filtros mudam.
final homeSearchPageProvider = NotifierProvider<HomeSearchPage, int>(
  HomeSearchPage.new,
);

/// Resultados PLPCG da query + filtros correntes — **síncronos**.
///
/// Observa manifest (via [plpcgCatalogSourceProvider]), query e filtros: um
/// refresh de manifest em segundo plano ou um chip de material re-derivam só
/// esta lista, sem tocar a rede.
final homeLocalSearchProvider = Provider<List<LouvorGroup>>((ref) {
  final query = ref.watch(homeSearchDebouncedQueryProvider);
  final filters = ref.watch(catalogFiltersProvider);
  final source = ref.watch(plpcgCatalogSourceProvider);
  return source.searchLocal(CatalogQuery(text: query, filters: filters));
});

/// Estado único da busca da Home — o que os widgets observam.
final homeSearchStateProvider = Provider<HomeSearchState>((ref) {
  final query = ref.watch(homeSearchDebouncedQueryProvider);
  final page = ref.watch(homeSearchPageProvider);
  final localGroups = ref.watch(homeLocalSearchProvider);

  if (query.trim().isEmpty) {
    // Sem query não há página remota: nada de `loading` e nada de rede — a
    // família nem chega a ser instanciada.
    return HomeSearchState(
      query: query,
      page: page,
      localGroups: localGroups,
      remote: const AsyncData(CatalogSearchPage.empty),
    );
  }

  final remote = ref.watch(
    homeRemoteSearchProvider(HomeRemoteSearchKey(query: query, page: page)),
  );

  return HomeSearchState(
    query: query,
    page: page,
    localGroups: localGroups,
    remote: remote,
  );
});

/// Re-dispara a busca remota da página corrente (linha de retry e reconexão).
///
/// Invalida só a chave `(query, página)` que está na tela: as outras páginas
/// já memoizadas continuam válidas.
void retryRemoteSearch(WidgetRef ref) {
  final query = ref.read(homeSearchDebouncedQueryProvider);
  final page = ref.read(homeSearchPageProvider);
  if (query.trim().isEmpty) return;
  ref.invalidate(
    homeRemoteSearchProvider(HomeRemoteSearchKey(query: query, page: page)),
  );
}

/// Texto cru da `SearchBar`, sem debounce.
class HomeSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  /// Registra a tecla recém-digitada.
  void setQuery(String query) {
    state = query;
  }
}

/// Debounce de 300 ms entre [homeSearchQueryProvider] e a busca.
class HomeSearchDebouncer extends Notifier<String> {
  Timer? _debounceTimer;

  @override
  String build() {
    ref.listen<String>(homeSearchQueryProvider, (_, _) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        // Lê o valor atual no fim do debounce — evita aplicar `next` obsoleto
        // se outro evento cancelou e reagendou o timer antes do disparo.
        state = ref.read(homeSearchQueryProvider);
      });
    });

    ref.onDispose(() => _debounceTimer?.cancel());
    return ref.read(homeSearchQueryProvider);
  }

  /// Hidrata busca a partir da URL sem esperar debounce.
  void setImmediate(String query) {
    ref.read(homeSearchQueryProvider.notifier).setQuery(query);
    _debounceTimer?.cancel();
    state = query;
  }
}

/// Página 1-based da busca remota.
///
/// O reset para 1 mora aqui (e não em quem digita) porque é a única regra que
/// liga query/filtros à paginação: quando a página já é 1, nada muda — e como
/// a chave remota é `(query, página)`, um chip de filtro não re-busca nada.
class HomeSearchPage extends Notifier<int> {
  @override
  int build() {
    ref.listen<String>(homeSearchDebouncedQueryProvider, (previous, next) {
      if (previous == next) return;
      state = 1;
    });
    ref.listen<CatalogFilterState>(catalogFiltersProvider, (_, _) {
      state = 1;
    });
    return 1;
  }

  /// Avança uma página.
  void next() {
    state = state + 1;
  }

  /// Volta uma página (nunca abaixo de 1).
  void previous() {
    if (state <= 1) return;
    state = state - 1;
  }
}

/// Debounce de 500ms para sync de URL `pesquisa=` (MAPEAMENTO §4.2).
final homeSearchUrlSyncQueryProvider =
    NotifierProvider<HomeSearchUrlDebouncer, String>(
      HomeSearchUrlDebouncer.new,
    );

/// Propaga [homeSearchDebouncedQueryProvider] após 500ms para `?pesquisa=`.
class HomeSearchUrlDebouncer extends Notifier<String> {
  Timer? _urlDebounceTimer;

  @override
  String build() {
    ref.listen<String>(homeSearchDebouncedQueryProvider, (previous, next) {
      _urlDebounceTimer?.cancel();
      _urlDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        state = next;
      });
    }, fireImmediately: true);

    ref.onDispose(() => _urlDebounceTimer?.cancel());
    return ref.read(homeSearchDebouncedQueryProvider);
  }
}
