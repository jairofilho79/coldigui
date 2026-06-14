import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/home_url_builder.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/filters_panel.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_search_results_sliver.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_bar.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// UC-01, UC-02 — Home / Pesquisador.
///
/// Busca com debounce 300ms, filtros material/arranjo em tempo real,
/// resultados como [LouvorGroupCard] (chips agrupados) e sync URL
/// (`pesquisa=`, `materiais=`, `arranjo=`).
///
/// **Ciclo de vida Riverpod:** hidratação de URL e `goRouter.go` são adiados com
/// `addPostFrameCallback` em [didUpdateWidget] e [_syncUrlFromState]
/// — evita `Tried to modify a provider while the widget tree was building` quando o
/// manifest (~4600 itens) conclui e a árvore reconstrói.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.initialSearchQuery = '',
    this.initialMateriais,
    this.initialArranjo,
  });

  /// Query inicial vinda de `?pesquisa=` na URL.
  final String initialSearchQuery;

  /// CSV inicial de `?materiais=` (omitido quando todos selecionados).
  final String? initialMateriais;

  /// CSV inicial de `?arranjo=` (omitido quando vazio = todos).
  final String? initialArranjo;

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

  static const double _maxContentWidth = 896;

  @override
  void initState() {
    super.initState();
    _searchBarInitialValue = widget.initialSearchQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromUrl());
  }

  void _hydrateFromUrl() {
    if (_initialized) return;
    _initialized = true;
    ref
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate(widget.initialSearchQuery);
    ref.read(catalogFiltersProvider.notifier).hydrateFromUrl(
          materiais: widget.initialMateriais,
          arranjo: widget.initialArranjo,
        );
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
        oldWidget.initialMateriais != widget.initialMateriais ||
            oldWidget.initialArranjo != widget.initialArranjo;
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
        ref.read(catalogFiltersProvider.notifier).hydrateFromUrl(
              materiais: widget.initialMateriais,
              arranjo: widget.initialArranjo,
            );
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
    final pesquisa = ref.read(homeSearchUrlSyncQueryProvider);
    final filters = ref.read(catalogFiltersProvider);

    final target = buildHomeLocation(
      pesquisa: pesquisa,
      materiais: filters.materiaisUrlValue,
      arranjo: filters.arranjoUrlValue,
    );

    if (buildHomeLocationFromUri(uri) == target) return;
    _suppressSearchHydrationFromOwnUrlSync = true;
    goRouter.go(target);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final manifestAsync = ref.watch(louvoresManifestProvider);

    ref.listen<String>(homeSearchUrlSyncQueryProvider, (_, __) {
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });

    ref.listen<CatalogFilterState>(catalogFiltersProvider, (_, __) {
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });

    final horizontalPadding =
        MediaQuery.sizeOf(context).width > 600 ? 24.0 : 16.0;

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
                    initiallyExpanded: widget.initialMateriais != null ||
                        widget.initialArranjo != null,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: SearchBar(
                    key: ValueKey(_searchHydrationEpoch),
                    hintText: l10n.searchHint,
                    initialValue: _searchBarInitialValue,
                    onQueryChanged: (value) {
                      ref.read(homeSearchRawQueryProvider.notifier).state =
                          value;
                    },
                  ),
                ),
                if (manifestAsync.isLoading) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  const SliverToBoxAdapter(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                  ),
                ],
                if (manifestAsync.hasError) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: Text(
                      l10n.catalogLoadError,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                ],
                if (manifestAsync.value?.isStale == true) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        l10n.catalogStaleBanner,
                        style: AppTypography.body.copyWith(
                          color: AppColors.title.withValues(alpha: 0.85),
                        ),
                      ),
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
