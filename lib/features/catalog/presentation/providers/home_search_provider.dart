import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../data/providers/plpcg_catalog_source_provider.dart';
import '../../data/sources/composite_catalog_source.dart';
import '../../domain/entities/catalog_query.dart';
import '../../domain/entities/louvor_group.dart';
import '../../domain/usecases/matches_catalog_filters.dart';
import 'catalog_filters_provider.dart';
import 'home_remote_search_provider.dart';
import 'home_search_state.dart';
import 'known_praise_ids_provider.dart';
import 'manifest_material_aliases_provider.dart';

/// Estado da busca e filtros na Home (UC-01 + UC-02 + pesquisa híbrida §6).
///
/// Pipeline declarativo (C.2):
/// ```
/// homeSearchQueryProvider (texto cru)
///   → homeSearchDebouncedQueryProvider (300 ms)
///       ├→ homeLocalSearchProvider   (PLPCG, depois Coldigom local fora do manifest; filtros)
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
/// primeiro e Coldigom depois, sem os praises que o manifest já cobre
/// (spec §5.2).
///
/// Observa manifest (via [plpcgCatalogSourceProvider]), o índice Coldigom
/// hidratado (via [coldigomCatalogSourceProvider]), query e filtros: um
/// refresh de manifest, um sync do catálogo Coldigom ou um chip de filtro
/// re-derivam só esta lista, sem tocar a rede. Os filtros do catálogo valem
/// para toda a lista (`matchesCatalogFilters`).
final homeLocalSearchProvider = Provider<List<LouvorGroup>>((ref) {
  final query = ref.watch(homeSearchDebouncedQueryProvider);
  final filters = ref.watch(catalogFiltersProvider);
  final plpcg = ref.watch(plpcgCatalogSourceProvider);
  final coldigom = ref.watch(coldigomCatalogSourceProvider);
  final catalogQuery = CatalogQuery(text: query);
  final merged = mergeLocalSearchResults(
    plpcg: plpcg.searchLocal(catalogQuery),
    coldigom: coldigom.searchLocal(catalogQuery),
    manifestPraiseIds: ref.watch(manifestMaterialAliasesProvider).praiseIds,
  );
  if (filters.isEmpty) return merged;
  return [
    for (final group in merged)
      if (matchesCatalogFilters(group, filters)) group,
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
  final filters = ref.watch(catalogFiltersProvider);
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
  // Os «novos» passam pelo mesmo predicado da lista local (spec §2.4), no
  // cliente — os nomes de tag não viram ids do servidor.
  final newGroups = [
    for (final g in remote.value?.groups ?? const <LouvorGroup>[])
      if (!localIds.contains(g.groupId) && matchesCatalogFilters(g, filters)) g,
  ];

  // Enquanto a hidratação ainda não devolveu valor, `coldigomSearchIndexProvider`
  // é `empty` (não "ainda não sei") — tratar isso como "nada é conhecido"
  // acenderia «N novos» de forma transitória a cada boot, mesmo para praises
  // que o Isar já tinha. Sem valor ainda, todo extra passa por conhecido:
  // sem chip, sem contar, até o índice real chegar.
  final hydration = ref.watch(coldigomCatalogHydrationProvider);
  final knownIds = hydration.hasValue
      ? ref.watch(knownPraiseIdsProvider)
      : {for (final g in newGroups) g.groupId};

  return HomeSearchState(
    query: query,
    localGroups: localGroups,
    remote: remote,
    newGroups: newGroups,
    // O índice pode conhecer um grupo que a busca textual local não achou
    // (tokens diferentes) — ele entra em `groups` do mesmo jeito (o remoto
    // achou), mas não é «novo» pro catálogo: só o chip some (§6.3).
    knownIds: knownIds,
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
