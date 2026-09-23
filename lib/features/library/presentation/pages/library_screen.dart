import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/routing/url_sync_navigation.dart';
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/library_url_builder.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/filters_panel.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card_skeleton.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/library/presentation/providers/library_group_results_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:coldigui/features/library/presentation/widgets/library_view_controls.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// UC-03 — /biblioteca: o catálogo local inteiro, filtrado (os mesmos filtros
/// da página inicial, [catalogFiltersProvider]), ordenado e paginado (spec
/// fim-fonte §2.3). Um caminho só: sem seletor de fonte, sem browse
/// remoto. Enquanto o índice está vazio mostra carregamento; índice vazio
/// com o sync falhado mostra `catalogLoadError` + «Tentar novamente».
/// Sync URL via [buildLibraryLocation].
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({
    super.key,
    this.initialTonality,
    this.initialRhythm,
    this.initialCategory,
    this.initialTags,
    this.initialMaterialKinds,
    this.initialOrdenar,
    this.initialItensPorPagina,
    this.initialPagina,
  });

  final String? initialTonality;
  final String? initialRhythm;
  final String? initialCategory;
  final String? initialTags;
  final String? initialMaterialKinds;
  final String? initialOrdenar;
  final String? initialItensPorPagina;
  final String? initialPagina;

  bool get _hasInitialFilters =>
      initialTonality != null ||
      initialRhythm != null ||
      initialCategory != null ||
      initialTags != null ||
      initialMaterialKinds != null;

  static const double _maxContentWidth = 896;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  var _initialized = false;
  var _urlSyncEnabled = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromUrl());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollResultsToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
  }

  void _hydrateFromUrl() {
    if (_initialized) return;
    _initialized = true;
    // Filtros antes da vista: os toggles voltam à página 1, a hidratação não;
    // a vista vem depois e manda na página.
    _hydrateFilters();
    _hydrateView();
    // C13: default de itens/página pela largura — só quando não há valor
    // gravado nem `itensPorPagina` na URL (no-op nos demais casos).
    ref
        .read(libraryViewSettingsProvider.notifier)
        .setDefaultForWidth(MediaQuery.sizeOf(context).width);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _urlSyncEnabled = true;
    });
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

  void _hydrateView() {
    ref
        .read(libraryViewSettingsProvider.notifier)
        .hydrateFromUrl(
          ordenar: widget.initialOrdenar,
          itensPorPagina: widget.initialItensPorPagina,
          pagina: widget.initialPagina,
        );
  }

  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final filtersChanged =
        oldWidget.initialTonality != widget.initialTonality ||
        oldWidget.initialRhythm != widget.initialRhythm ||
        oldWidget.initialCategory != widget.initialCategory ||
        oldWidget.initialTags != widget.initialTags ||
        oldWidget.initialMaterialKinds != widget.initialMaterialKinds;
    final viewChanged =
        oldWidget.initialOrdenar != widget.initialOrdenar ||
        oldWidget.initialItensPorPagina != widget.initialItensPorPagina ||
        oldWidget.initialPagina != widget.initialPagina;
    if (!filtersChanged && !viewChanged) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (filtersChanged) _hydrateFilters();
      if (viewChanged) _hydrateView();
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
    final filters = ref.read(catalogFiltersProvider);
    final view = ref.read(libraryViewSettingsProvider);
    final target = buildLibraryLocation(
      tonality: filters.tonalityUrlValue,
      rhythm: filters.rhythmUrlValue,
      category: filters.categoryUrlValue,
      tags: filters.tagsUrlValue,
      materialKinds: filters.materialKindsUrlValue,
      ordenar: view.ordenarUrlValue ?? view.sortBy,
      itensPorPagina: view.itensPorPaginaUrlValue ?? '${view.itemsPerPage}',
      pagina: view.paginaUrlValue ?? '${view.page}',
    );

    if (buildLibraryLocationFromUri(uri) == target) return;
    // Filtros, ordenação e página espelham estado — replaceState (P4).
    goReplacingUrl(context, goRouter, target);
  }

  void _retryCatalog() {
    unawaited(ref.read(coldigomCatalogSyncProvider.notifier).sync());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = ref.watch(catalogIndexStatusProvider);
    final results = ref.watch(libraryGroupResultsProvider);

    ref.listen<CatalogFilterState>(catalogFiltersProvider, (_, _) {
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });

    ref.listen<LibraryViewSettings>(libraryViewSettingsProvider, (
      previous,
      next,
    ) {
      if (previous?.page != next.page ||
          previous?.sortBy != next.sortBy ||
          previous?.itemsPerPage != next.itemsPerPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollResultsToTop();
        });
      }
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });

    // Reconexão (C.8): a rede volta (offline → online) com o catálogo vazio
    // → tenta de novo sozinho (spec §2.1). Só na transição: o primeiro
    // `true` do stream (vindo de loading) ou um `true` repetido não contam —
    // o boot já sincroniza e o índice pode só não ter hidratado ainda.
    ref.listen<AsyncValue<bool>>(connectivityStreamProvider, (previous, next) {
      final wasOffline = previous?.value == false;
      if (!wasOffline || next.value != true) return;
      if (ref.read(coldigomSearchIndexProvider).isEmpty) _retryCatalog();
    });

    final horizontalPadding = MediaQuery.sizeOf(context).width > 600
        ? 24.0
        : 16.0;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: LibraryScreen._maxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FiltersPanel(
                        initiallyExpanded: widget._hasInitialFilters,
                      ),
                      const SizedBox(height: 12),
                      const LibraryViewControls(),
                      if (status == CatalogIndexStatus.failed) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.catalogLoadError,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: FilledButton(
                            onPressed: _retryCatalog,
                            child: Text(l10n.retry),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (status == CatalogIndexStatus.loading)
                  const CatalogLoadingSliver()
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index < results.items.length - 1 ? 8 : 0,
                        ),
                        child: LouvorGroupCard(group: results.items[index]),
                      ),
                      childCount: results.items.length,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
