import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../data/providers/plpcg_catalog_source_provider.dart';
import '../../domain/entities/catalog_query.dart';
import '../../domain/entities/louvor_group.dart';
import 'catalog_filters_provider.dart';
import 'home_remote_search_provider.dart';
import 'home_search_state.dart';

/// Estado da busca e filtros na Home (UC-01 + UC-02 + pesquisa híbrida §6).
///
/// Pipeline declarativo (C.2):
/// ```
/// homeSearchQueryProvider (texto cru)
///   → homeSearchDebouncedQueryProvider (300 ms)
///       ├→ homeLocalSearchProvider   (PLPCG + filtros, depois Coldigom local)
///       └→ homeRemoteSearchProvider((query, 1))  (Coldigom, valida; só com rede)
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

/// Resultados locais da query + filtros correntes — **síncronos**, PLPCG
/// primeiro e Coldigom depois (O16).
///
/// Observa manifest (via [plpcgCatalogSourceProvider]), o índice Coldigom
/// hidratado (via [coldigomCatalogSourceProvider]), query e filtros: um
/// refresh de manifest, um sync do catálogo Coldigom ou um chip de material
/// re-derivam só esta lista, sem tocar a rede. Os filtros UC-02 valem só
/// para o PLPCG.
final homeLocalSearchProvider = Provider<List<LouvorGroup>>((ref) {
  final query = ref.watch(homeSearchDebouncedQueryProvider);
  final filters = ref.watch(catalogFiltersProvider);
  final plpcg = ref.watch(plpcgCatalogSourceProvider);
  final coldigom = ref.watch(coldigomCatalogSourceProvider);
  final catalogQuery = CatalogQuery(text: query, filters: filters);
  return [
    ...plpcg.searchLocal(catalogQuery),
    ...coldigom.searchLocal(catalogQuery),
  ];
});

/// Estado único da busca da Home — o que os widgets observam.
///
/// A lista é a local (PLPCG + Coldigom do índice); o remoto só valida (O15):
/// sem rede nem é instanciado (`offline`), com rede o que ele trouxer a mais
/// entra em `newGroups`, no fim, na ordem remota.
final homeSearchStateProvider = Provider<HomeSearchState>((ref) {
  final query = ref.watch(homeSearchDebouncedQueryProvider);
  final localGroups = ref.watch(homeLocalSearchProvider);
  // Observado incondicionalmente (mesmo com query vazia): assim o provider
  // já está de pé — e resolvido — quando a primeira query chega, em vez de
  // nascer `AsyncLoading` bem na hora em que a Home mais precisa saber se
  // há rede. `AsyncLoading` inicial conta como online, como no resto da
  // Home; só um `false` explícito segura o remoto. `select` porque só o
  // booleano importa — um `AsyncValue` novo com o mesmo `.value` não deve
  // reconstruir este provider.
  final online = ref.watch(
    connectivityStreamProvider.select((c) => c.value ?? true),
  );

  if (query.trim().isEmpty) {
    // Sem query não há página remota: nada de `loading` e nada de rede — a
    // família nem chega a ser instanciada.
    return HomeSearchState(
      query: query,
      localGroups: localGroups,
      remote: const AsyncData(CatalogSearchPage.empty),
    );
  }

  if (!online) {
    return HomeSearchState(
      query: query,
      localGroups: localGroups,
      remote: const AsyncLoading(),
      offline: true,
    );
  }

  final remote = ref.watch(
    homeRemoteSearchProvider(HomeRemoteSearchKey(query: query, page: 1)),
  );
  final localIds = {for (final g in localGroups) g.groupId};
  final newGroups = [
    for (final g in remote.value?.groups ?? const <LouvorGroup>[])
      if (!localIds.contains(g.groupId)) g,
  ];

  return HomeSearchState(
    query: query,
    localGroups: localGroups,
    remote: remote,
    newGroups: newGroups,
    // O índice pode conhecer um grupo que a busca textual local não achou
    // (tokens diferentes) — ele entra em `groups` do mesmo jeito (o remoto
    // achou), mas não é «novo» pro catálogo: só o chip some (§6.3).
    knownIds: ref.watch(coldigomSearchIndexProvider).praiseIds,
  );
});

/// Re-dispara a validação remota da query corrente (linha de estado e
/// reconexão). Invalida só a chave `(query, 1)` que está na tela.
void retryRemoteSearch(WidgetRef ref) {
  final query = ref.read(homeSearchDebouncedQueryProvider);
  if (query.trim().isEmpty) return;
  ref.invalidate(
    homeRemoteSearchProvider(HomeRemoteSearchKey(query: query, page: 1)),
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
