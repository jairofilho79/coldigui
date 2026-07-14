import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';

import '../../domain/entities/louvor_group.dart';
import '../../domain/entities/louvores_manifest.dart';
import 'catalog_filters_provider.dart';
import 'home_search_worker.dart';
import 'louvores_manifest_provider.dart';

/// Estado da busca e filtros na Home (UC-01 + UC-02).
///
/// Pipeline: [homeSearchRawQueryProvider] → debounce 300ms
/// ([homeSearchDebouncedQueryProvider]) → busca + filtros + agrupamento
/// off-main-thread ([homeSearchPipelineDriverProvider]) →
/// [homeSearchGroupResultsDataProvider] → [homeSearchGroupResultsProvider]
/// → [LouvorGroupCard].
/// Sync URL: [homeSearchUrlSyncQueryProvider] + [catalogFiltersProvider]
/// consumidos por [HomeScreen] → [buildHomeLocation].
///
/// Texto imediato digitado na [SearchBar] (sem debounce).
final homeSearchRawQueryProvider = StateProvider<String>((ref) => '');

/// Query debounced 300ms — dispara filtragem UC-01.
final homeSearchDebouncedQueryProvider =
    NotifierProvider<HomeSearchDebouncer, String>(HomeSearchDebouncer.new);

/// `true` enquanto a busca coldigom está em andamento (após resultados PLPCG).
final homeSearchColdigomLoadingProvider = StateProvider<bool>((ref) => false);

/// Página 1-based da busca coldigom (limit fixo 20).
final homeSearchColdigomPageProvider = StateProvider<int>((ref) => 1);

/// Heurística: última página coldigom veio cheia (`length >= limit`).
final homeSearchColdigomHasNextProvider = StateProvider<bool>((ref) => false);

/// Grupos PLPCG da query atual (sempre no topo da lista).
final homeSearchPlpcgGroupsDataProvider = StateProvider<List<LouvorGroup>>(
  (ref) => const [],
);

/// Grupos coldigom da [homeSearchColdigomPageProvider] atual.
final homeSearchColdigomGroupsDataProvider = StateProvider<List<LouvorGroup>>(
  (ref) => const [],
);

/// Cache combinado PLPCG + coldigom — atualizado pelo pipeline assíncrono.
final homeSearchGroupResultsDataProvider = Provider<List<LouvorGroup>>((ref) {
  return [
    ...ref.watch(homeSearchPlpcgGroupsDataProvider),
    ...ref.watch(homeSearchColdigomGroupsDataProvider),
  ];
});

/// Grupos agrupados por `groupId` para [LouvorGroupCard] na Home.
///
/// Interface síncrona (como antes) — apenas [HomeSearchResultsSliver] observa
/// este provider; a [SearchBar] não é reconstruída quando os resultados mudam.
final homeSearchGroupResultsProvider = Provider<List<LouvorGroup>>((ref) {
  ref.watch(homeSearchPipelineDriverProvider);
  return ref.watch(homeSearchGroupResultsDataProvider);
});

/// Executa o pipeline fora do main thread. Sobrescrever em testes se necessário.
final homeSearchPipelineExecutorProvider = Provider<HomeSearchPipelineExecutor>(
  (ref) {
    return (input) => compute(runHomeSearchPipeline, input);
  },
);

/// Dispara busca UC-01 + filtros UC-02 + agrupamento fora do main thread.
final homeSearchPipelineDriverProvider =
    NotifierProvider<HomeSearchPipelineDriver, int>(
      HomeSearchPipelineDriver.new,
    );

/// Debounce de 300ms entre [homeSearchRawQueryProvider] e filtragem.
class HomeSearchDebouncer extends Notifier<String> {
  Timer? _debounceTimer;

  @override
  String build() {
    ref.listen<String>(homeSearchRawQueryProvider, (_, _) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        // Lê o valor atual no fim do debounce — evita aplicar `next` obsoleto
        // se outro evento cancelou e reagendou o timer antes do disparo.
        state = ref.read(homeSearchRawQueryProvider);
      });
    }, fireImmediately: true);

    ref.onDispose(() => _debounceTimer?.cancel());
    return ref.read(homeSearchRawQueryProvider);
  }

  /// Hidrata busca a partir da URL sem esperar debounce.
  void setImmediate(String query) {
    ref.read(homeSearchRawQueryProvider.notifier).state = query;
    _debounceTimer?.cancel();
    state = query;
  }
}

/// Executa o pipeline da Home fora do main thread; descarta resultados obsoletos.
class HomeSearchPipelineDriver extends Notifier<int> {
  int _generation = 0;

  @override
  int build() {
    ref.listen<String>(homeSearchDebouncedQueryProvider, (_, _) {
      _resetPageAndSearch();
    }, fireImmediately: true);
    ref.listen<CatalogFilterState>(catalogFiltersProvider, (_, _) {
      _resetPageAndSearch();
    });
    ref.listen<AsyncValue<LouvoresManifest>>(louvoresManifestProvider, (_, _) {
      _resetPageAndSearch();
    }, fireImmediately: true);
    ref.listen<int>(homeSearchColdigomPageProvider, (previous, next) {
      if (previous == next) return;
      _scheduleSearch();
    });

    return 0;
  }

  void _resetPageAndSearch() {
    if (ref.read(homeSearchColdigomPageProvider) != 1) {
      // A mudança de página dispara o listen de page → um único search.
      ref.read(homeSearchColdigomPageProvider.notifier).state = 1;
      return;
    }
    _scheduleSearch();
  }

  void _scheduleSearch() {
    Future.microtask(() => unawaited(_runSearch()));
  }

  void _clearResults() {
    ref.read(homeSearchPlpcgGroupsDataProvider.notifier).state = const [];
    ref.read(homeSearchColdigomGroupsDataProvider.notifier).state = const [];
    ref.read(homeSearchColdigomHasNextProvider.notifier).state = false;
    ref.read(homeSearchColdigomLoadingProvider.notifier).state = false;
  }

  Future<void> _runSearch() async {
    final query = ref.read(homeSearchDebouncedQueryProvider);
    final filters = ref.read(catalogFiltersProvider);
    final catalog = ref.read(louvoresManifestProvider).value?.louvores;
    final page = ref.read(homeSearchColdigomPageProvider);

    if (query.trim().isEmpty) {
      _generation++;
      _clearResults();
      return;
    }

    final generation = ++_generation;

    List<LouvorGroup> groupsPlpcg = const [];
    if (catalog != null) {
      final input = HomeSearchPipelineInput(
        catalog: List.of(catalog),
        query: query,
        selectedMaterials: filters.selectedMaterials,
        selectedArranjos: filters.selectedArranjos,
      );

      final execute = ref.read(homeSearchPipelineExecutorProvider);
      groupsPlpcg = await execute(input);

      if (generation != _generation) return;

      ref.read(homeSearchPlpcgGroupsDataProvider.notifier).state = groupsPlpcg;
      // Mantém coldigom da página anterior até a nova resposta chegar.
    }

    ref.read(homeSearchColdigomLoadingProvider.notifier).state = true;
    // Evita mostrar página anterior enquanto a nova chega.
    ref.read(homeSearchColdigomGroupsDataProvider.notifier).state = const [];

    try {
      final coldigomResult = await ref
          .read(coldigomSearchRepositoryProvider)
          .search(query, page: page);

      if (generation != _generation) return;

      ref
          .read(coldigomLouvoresCacheProvider.notifier)
          .mergeLouvores(coldigomResult.louvores);

      ref.read(homeSearchColdigomGroupsDataProvider.notifier).state =
          coldigomResult.groups;
      ref.read(homeSearchColdigomHasNextProvider.notifier).state =
          coldigomResult.hasNextPage;
    } on Object {
      if (generation != _generation) return;
      // Mantém resultados PLPCG já exibidos; limpa coldigom desta página.
      ref.read(homeSearchColdigomGroupsDataProvider.notifier).state = const [];
      ref.read(homeSearchColdigomHasNextProvider.notifier).state = false;
    } finally {
      if (generation == _generation) {
        ref.read(homeSearchColdigomLoadingProvider.notifier).state = false;
      }
    }
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
