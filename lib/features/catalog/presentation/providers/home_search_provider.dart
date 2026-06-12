import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/catalog_providers.dart';
import '../../domain/entities/louvor.dart';
import 'catalog_filters_provider.dart';
import 'louvores_manifest_provider.dart';

/// Estado da busca e filtros na Home (UC-01 + UC-02).
///
/// Pipeline: [homeSearchRawQueryProvider] → debounce 300ms
/// ([homeSearchDebouncedQueryProvider]) → [SearchLouvorByNumberOrText]
/// → [FilterByMaterialAndArranjo] via [homeSearchResultsProvider].
/// Sync URL: [homeSearchUrlSyncQueryProvider] + [catalogFiltersProvider]
/// consumidos por [HomeScreen] → [buildHomeLocation].
///
/// Texto imediato digitado na [SearchBar] (sem debounce).
final homeSearchRawQueryProvider = StateProvider<String>((ref) => '');

/// Query debounced 300ms — dispara filtragem UC-01.
final homeSearchDebouncedQueryProvider =
    NotifierProvider<HomeSearchDebouncer, String>(HomeSearchDebouncer.new);

/// Resultados da Home: busca UC-01 aplicada antes de filtros UC-02.
final homeSearchResultsProvider = Provider<List<Louvor>>((ref) {
  final query = ref.watch(homeSearchDebouncedQueryProvider);
  final filters = ref.watch(catalogFiltersProvider);
  final manifestAsync = ref.watch(louvoresManifestProvider);
  final search = ref.watch(searchLouvorByNumberOrTextProvider);
  final filterByMaterial = ref.watch(filterByMaterialAndArranjoProvider);

  return manifestAsync.when(
    skipLoadingOnReload: true,
    data: (catalog) {
      final searched = search(catalog, query);
      return filterByMaterial(
        searched,
        selectedMaterials: filters.selectedMaterials,
        selectedArranjos: filters.selectedArranjos,
      );
    },
    loading: () => const [],
    error: (_, __) => const [],
  );
});

/// Debounce de 300ms entre [homeSearchRawQueryProvider] e filtragem.
class HomeSearchDebouncer extends Notifier<String> {
  Timer? _debounceTimer;

  @override
  String build() {
    ref.listen<String>(
      homeSearchRawQueryProvider,
      (_, __) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          // Lê o valor atual no fim do debounce — evita aplicar `next` obsoleto
          // se outro evento cancelou e reagendou o timer antes do disparo.
          state = ref.read(homeSearchRawQueryProvider);
        });
      },
      fireImmediately: true,
    );

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
    ref.listen<String>(
      homeSearchDebouncedQueryProvider,
      (previous, next) {
        _urlDebounceTimer?.cancel();
        _urlDebounceTimer = Timer(const Duration(milliseconds: 500), () {
          state = next;
        });
      },
      fireImmediately: true,
    );

    ref.onDispose(() => _urlDebounceTimer?.cancel());
    return ref.read(homeSearchDebouncedQueryProvider);
  }
}
