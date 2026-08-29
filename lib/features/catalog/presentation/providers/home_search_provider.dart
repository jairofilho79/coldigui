import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';

import '../../domain/entities/louvor_group.dart';

/// Estado da busca na Home (UC-01) — só Coldigom neste build.
///
/// Pipeline: [homeSearchRawQueryProvider] → debounce 300ms
/// ([homeSearchDebouncedQueryProvider]) → [homeSearchPipelineDriverProvider]
/// → [homeSearchGroupResultsDataProvider] → [homeSearchGroupResultsProvider]
/// → [LouvorGroupCard].
/// Sync URL: [homeSearchUrlSyncQueryProvider] consumido por [HomeScreen].
///
/// Texto imediato digitado na [SearchBar] (sem debounce).
final homeSearchRawQueryProvider = StateProvider<String>((ref) => '');

/// Query debounced 300ms — dispara filtragem UC-01.
final homeSearchDebouncedQueryProvider =
    NotifierProvider<HomeSearchDebouncer, String>(HomeSearchDebouncer.new);

/// `true` enquanto a busca coldigom está em andamento.
final homeSearchColdigomLoadingProvider = StateProvider<bool>((ref) => false);

/// Página 1-based da busca coldigom (limit fixo 20).
final homeSearchColdigomPageProvider = StateProvider<int>((ref) => 1);

/// Heurística: última página coldigom veio cheia (`length >= limit`).
final homeSearchColdigomHasNextProvider = StateProvider<bool>((ref) => false);

/// Grupos PLPCG — sempre vazio neste build (só Coldigom).
final homeSearchPlpcgGroupsDataProvider = StateProvider<List<LouvorGroup>>(
  (ref) => const [],
);

/// Grupos coldigom da [homeSearchColdigomPageProvider] atual.
final homeSearchColdigomGroupsDataProvider = StateProvider<List<LouvorGroup>>(
  (ref) => const [],
);

/// Resultados da Home — só Coldigom.
final homeSearchGroupResultsDataProvider = Provider<List<LouvorGroup>>((ref) {
  return ref.watch(homeSearchColdigomGroupsDataProvider);
});

/// Grupos agrupados por `groupId` para [LouvorGroupCard] na Home.
///
/// Interface síncrona — apenas [HomeSearchResultsSliver] observa este provider;
/// a [SearchBar] não é reconstruída quando os resultados mudam.
final homeSearchGroupResultsProvider = Provider<List<LouvorGroup>>((ref) {
  ref.watch(homeSearchPipelineDriverProvider);
  return ref.watch(homeSearchGroupResultsDataProvider);
});

/// Dispara busca Coldigom fora do main thread (rede).
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

/// Executa a busca Coldigom; descarta resultados obsoletos.
class HomeSearchPipelineDriver extends Notifier<int> {
  int _generation = 0;

  @override
  int build() {
    ref.listen<String>(homeSearchDebouncedQueryProvider, (_, _) {
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
    final page = ref.read(homeSearchColdigomPageProvider);

    if (query.trim().isEmpty) {
      _generation++;
      _clearResults();
      return;
    }

    final generation = ++_generation;

    ref.read(homeSearchPlpcgGroupsDataProvider.notifier).state = const [];
    ref.read(homeSearchColdigomLoadingProvider.notifier).state = true;
    ref.read(homeSearchColdigomGroupsDataProvider.notifier).state = const [];

    try {
      final coldigomResult = await ref
          .read(coldigomSearchRepositoryProvider)
          .search(query, page: page);

      if (generation != _generation) return;

      ref
          .read(coldigomLouvoresCacheProvider.notifier)
          .mergeLouvores(coldigomResult.louvores);
      ref
          .read(coldigomAudioTracksCacheProvider.notifier)
          .mergeTracks(coldigomResult.audioTracks);
      ref
          .read(coldigomPraiseMetaCacheProvider.notifier)
          .mergeMeta(coldigomResult.praiseMetaByGroupId);

      ref.read(homeSearchColdigomGroupsDataProvider.notifier).state =
          coldigomResult.groups;
      ref.read(homeSearchColdigomHasNextProvider.notifier).state =
          coldigomResult.hasNextPage;
    } on Object {
      if (generation != _generation) return;
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
