import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/platform/platform_capabilities_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/routing/url_sync_navigation.dart';
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/home_url_builder.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/app_shortcuts.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/recently_opened_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/filters_panel.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_search_results_sliver.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card_skeleton.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_bar.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// UC-01, UC-02 — página inicial / Pesquisador.
///
/// Busca com debounce 300ms no índice local do catálogo, filtros do catálogo
/// (tom, ritmo, categoria, tags, tipo de material — os mesmos da
/// /biblioteca), resultados como [LouvorGroupCard] e sync URL (`pesquisa=` +
/// params de filtro, spec fim-fonte §2.5). Enquanto o índice está vazio
/// mostra carregamento; vazio com o sync falhado mostra `catalogLoadError` +
/// «Tentar novamente».
///
/// **Ciclo de vida Riverpod:** hidratação de URL e `goRouter.go` são adiados com
/// `addPostFrameCallback` em [didUpdateWidget] e [_syncUrlFromState]
/// — evita `Tried to modify a provider while the widget tree was building`
/// quando o índice (~2063 grupos) conclui e a árvore reconstrói.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.initialSearchQuery = '',
    this.initialTonality,
    this.initialRhythm,
    this.initialCategory,
    this.initialTags,
    this.initialMaterialKinds,
  });

  /// Query inicial vinda de `?pesquisa=` na URL.
  final String initialSearchQuery;

  /// CSVs iniciais dos filtros do catálogo (`?tonality=`, `?rhythm=`,
  /// `?category=`, `?tags=` por nome, `?materialKinds=` por id de kind).
  final String? initialTonality;
  final String? initialRhythm;
  final String? initialCategory;
  final String? initialTags;
  final String? initialMaterialKinds;

  bool get _hasInitialFilters =>
      initialTonality != null ||
      initialRhythm != null ||
      initialCategory != null ||
      initialTags != null ||
      initialMaterialKinds != null;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _initialized = false;
  var _urlSyncEnabled = false;

  /// Evita hidratar busca quando [goRouter.go] foi disparado por este widget
  /// (eco de URL) — o usuário pode ter digitado além do valor já sincronizado.
  var _suppressSearchHydrationFromOwnUrlSync = false;

  /// Recria [SearchBar] só em hidratação externa (deep link, voltar no histórico).
  var _searchHydrationEpoch = 0;

  /// Valor inicial da [SearchBar] — não segue `?pesquisa=` a cada sync de URL.
  late String _searchBarInitialValue;

  /// Vive na tela, não na [SearchBar]: o `Ctrl+K` precisa de um nó estável
  /// mesmo quando a barra é recriada pela hidratação de URL.
  final _searchFocusNode = FocusNode(debugLabel: 'homeSearch');

  static const double _maxContentWidth = 896;

  /// Filtros gravados (C13) ao montar: restringem os resultados mesmo sem
  /// nada na URL, então o painel abre para mostrá-los.
  late final bool _hadSavedFiltersAtMount;

  @override
  void initState() {
    super.initState();
    _hadSavedFiltersAtMount = !ref.read(catalogFiltersProvider).isEmpty;
    _searchBarInitialValue = widget.initialSearchQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromUrl());
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _focusSearchField() {
    _searchFocusNode.requestFocus();
  }

  void _hydrateFilters() {
    ref
        .read(catalogFiltersProvider.notifier)
        .hydrateFromUrl(
          tonality: widget.initialTonality,
          rhythm: widget.initialRhythm,
          category: widget.initialCategory,
          tags: widget.initialTags,
          materialKinds: widget.initialMaterialKinds,
        );
  }

  void _hydrateFromUrl() {
    if (_initialized) return;
    _initialized = true;
    ref
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate(widget.initialSearchQuery);
    _hydrateFilters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _urlSyncEnabled = true;
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final searchChanged =
        oldWidget.initialSearchQuery != widget.initialSearchQuery;
    final filtersChanged =
        oldWidget.initialTonality != widget.initialTonality ||
        oldWidget.initialRhythm != widget.initialRhythm ||
        oldWidget.initialCategory != widget.initialCategory ||
        oldWidget.initialTags != widget.initialTags ||
        oldWidget.initialMaterialKinds != widget.initialMaterialKinds;
    if (!searchChanged && !filtersChanged) return;

    // Riverpod proíbe modificar providers durante o ciclo de build/update.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ownUrlSyncEcho = _suppressSearchHydrationFromOwnUrlSync;
      if (ownUrlSyncEcho) {
        _suppressSearchHydrationFromOwnUrlSync = false;
      }
      if (searchChanged && !ownUrlSyncEcho) {
        ref
            .read(homeSearchDebouncedQueryProvider.notifier)
            .setImmediate(widget.initialSearchQuery);
        setState(() {
          _searchBarInitialValue = widget.initialSearchQuery;
          _searchHydrationEpoch++;
        });
      }
      if (filtersChanged) {
        _hydrateFilters();
      }
    });
  }

  void _syncUrlFromState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyUrlSyncFromState();
    });
  }

  void _applyUrlSyncFromState() {
    final goRouter = GoRouter.maybeOf(context);
    if (goRouter == null) return;

    final uri = goRouter.routerDelegate.currentConfiguration.uri;
    // Aba fora de cena (ramo do shell ainda montado): os filtros são
    // partilhados com a /biblioteca e mexer neles lá não pode trazer o
    // usuário para cá. Só a rota corrente espelha estado na URL.
    if (uri.path != RoutePaths.home) return;
    final pesquisa = ref.read(homeSearchUrlSyncQueryProvider);
    final filters = ref.read(catalogFiltersProvider);

    final target = buildHomeLocation(
      pesquisa: pesquisa,
      tonality: filters.tonalityUrlValue,
      rhythm: filters.rhythmUrlValue,
      category: filters.categoryUrlValue,
      tags: filters.tagsUrlValue,
      materialKinds: filters.materialKindsUrlValue,
    );

    if (buildHomeLocationFromUri(uri) == target) return;
    _suppressSearchHydrationFromOwnUrlSync = true;
    // replaceState, não pushState: digitar não pode poluir o voltar (P4).
    goReplacingUrl(context, goRouter, target);
  }

  /// Re-hidrata (a leitura local pode ter sido o que falhou) e sincroniza.
  void _retryCatalog() {
    ref.invalidate(coldigomCatalogHydrationProvider);
    unawaited(ref.read(coldigomCatalogSyncProvider.notifier).sync());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = ref.watch(catalogIndexStatusProvider);
    // Mantém o `recentlyOpenedProvider` com um observador vivo enquanto a
    // Home existe — sem isto os `ref.listen` internos dele (leitor/cifra,
    // sessão de áudio) não disparam (Riverpod 3.3, ver docstring do provider).
    ref.watch(recentlyOpenedProvider);

    ref.listen<String>(homeSearchUrlSyncQueryProvider, (_, _) {
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });

    ref.listen<CatalogFilterState>(catalogFiltersProvider, (_, _) {
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });

    ref.listen<int>(searchFocusRequestProvider, (_, _) => _focusSearchField());

    // Reconexão (C.8): volta a rede com o catálogo em erro ou a página
    // remota em erro → tenta de novo sozinho, sem esperar o usuário tocar em
    // «Tentar novamente» (spec §2.1). Qualquer `true` conta — na web o
    // connectivity_plus não emite valor inicial, e depois de um arranque
    // offline o primeiro `true` chega direto de loading. O gatilho é o
    // estado `failed`: no boot ele ainda é `loading`, então o primeiro
    // `true` nativo não sincroniza em dobro (e `sync()` deduplica).
    ref.listen<AsyncValue<bool>>(connectivityStreamProvider, (previous, next) {
      if (next.value != true) return;
      if (ref.read(catalogIndexStatusProvider) == CatalogIndexStatus.failed) {
        _retryCatalog();
      }
      if (ref.read(homeSearchStateProvider).remoteFailed) {
        retryRemoteSearch(ref);
      }
    });

    final horizontalPadding = MediaQuery.sizeOf(context).width > 600
        ? 24.0
        : 16.0;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: FiltersPanel(
                    initiallyExpanded:
                        widget._hasInitialFilters || _hadSavedFiltersAtMount,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: SearchBar(
                    key: ValueKey(_searchHydrationEpoch),
                    hintText: l10n.searchHint,
                    initialValue: _searchBarInitialValue,
                    focusNode: _searchFocusNode,
                    capabilities: ref.read(platformCapabilitiesProvider),
                    onQueryChanged: (value) {
                      ref
                          .read(homeSearchQueryProvider.notifier)
                          .setQuery(value);
                    },
                  ),
                ),
                if (status == CatalogIndexStatus.loading) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  const CatalogLoadingSliver(),
                ],
                if (status == CatalogIndexStatus.failed) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.catalogLoadError,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _retryCatalog,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const HomeSearchResultsSliver(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
