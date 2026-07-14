import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/library_url_builder.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/filters_panel.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card_skeleton.dart';
import 'package:coldigui/features/library/domain/entities/library_catalog_mode.dart';
import 'package:coldigui/features/library/presentation/providers/coldigom_library_filters_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_catalog_mode_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_coldigom_browse_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_group_results_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_special_arrangement_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:coldigui/features/library/presentation/widgets/coldigom_library_filters.dart';
import 'package:coldigui/features/library/presentation/widgets/library_catalog_mode_toggle.dart';
import 'package:coldigui/features/library/presentation/widgets/library_view_controls.dart';
import 'package:coldigui/features/library/presentation/widgets/special_arrangement_filters.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// UC-03 — Biblioteca paginada (Fase 1.4).
///
/// Modo PLPCG: ordenação, paginação e filtros UC-02 + arranjo especial.
/// Modo Coldigom: listagem online com filtros server-side.
/// Sync URL via [buildLibraryLocation].
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({
    super.key,
    this.initialFonte,
    this.initialMateriais,
    this.initialArranjo,
    this.initialArranjoEspecial,
    this.initialTonality,
    this.initialRhythm,
    this.initialCategory,
    this.initialTags,
    this.initialMaterialKinds,
    this.initialOrdenar,
    this.initialItensPorPagina,
    this.initialPagina,
  });

  final String? initialFonte;
  final String? initialMateriais;
  final String? initialArranjo;
  final String? initialArranjoEspecial;
  final String? initialTonality;
  final String? initialRhythm;
  final String? initialCategory;
  final String? initialTags;
  final String? initialMaterialKinds;
  final String? initialOrdenar;
  final String? initialItensPorPagina;
  final String? initialPagina;

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
    ref
        .read(libraryCatalogModeProvider.notifier)
        .hydrateFromUrl(fonte: widget.initialFonte);
    ref
        .read(catalogFiltersProvider.notifier)
        .hydrateFromUrl(
          materiais: widget.initialMateriais,
          arranjo: widget.initialArranjo,
        );
    ref
        .read(librarySpecialArrangementProvider.notifier)
        .hydrateFromUrl(arranjoEspecial: widget.initialArranjoEspecial);
    ref
        .read(coldigomLibraryFiltersProvider.notifier)
        .hydrateFromUrl(
          tonality: widget.initialTonality,
          rhythm: widget.initialRhythm,
          category: widget.initialCategory,
          tags: widget.initialTags,
          materialKinds: widget.initialMaterialKinds,
        );
    ref
        .read(libraryViewSettingsProvider.notifier)
        .hydrateFromUrl(
          ordenar: widget.initialOrdenar,
          itensPorPagina: widget.initialItensPorPagina,
          pagina: widget.initialPagina,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _urlSyncEnabled = true;
    });
  }

  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final modeChanged = oldWidget.initialFonte != widget.initialFonte;
    final filtersChanged =
        oldWidget.initialMateriais != widget.initialMateriais ||
        oldWidget.initialArranjo != widget.initialArranjo;
    final specialChanged =
        oldWidget.initialArranjoEspecial != widget.initialArranjoEspecial;
    final coldigomChanged =
        oldWidget.initialTonality != widget.initialTonality ||
        oldWidget.initialRhythm != widget.initialRhythm ||
        oldWidget.initialCategory != widget.initialCategory ||
        oldWidget.initialTags != widget.initialTags ||
        oldWidget.initialMaterialKinds != widget.initialMaterialKinds;
    final viewChanged =
        oldWidget.initialOrdenar != widget.initialOrdenar ||
        oldWidget.initialItensPorPagina != widget.initialItensPorPagina ||
        oldWidget.initialPagina != widget.initialPagina;
    if (!modeChanged &&
        !filtersChanged &&
        !specialChanged &&
        !coldigomChanged &&
        !viewChanged) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (modeChanged) {
        ref
            .read(libraryCatalogModeProvider.notifier)
            .hydrateFromUrl(fonte: widget.initialFonte);
      }
      if (filtersChanged) {
        ref
            .read(catalogFiltersProvider.notifier)
            .hydrateFromUrl(
              materiais: widget.initialMateriais,
              arranjo: widget.initialArranjo,
            );
      }
      if (specialChanged) {
        ref
            .read(librarySpecialArrangementProvider.notifier)
            .hydrateFromUrl(arranjoEspecial: widget.initialArranjoEspecial);
      }
      if (coldigomChanged) {
        ref
            .read(coldigomLibraryFiltersProvider.notifier)
            .hydrateFromUrl(
              tonality: widget.initialTonality,
              rhythm: widget.initialRhythm,
              category: widget.initialCategory,
              tags: widget.initialTags,
              materialKinds: widget.initialMaterialKinds,
            );
      }
      if (viewChanged) {
        ref
            .read(libraryViewSettingsProvider.notifier)
            .hydrateFromUrl(
              ordenar: widget.initialOrdenar,
              itensPorPagina: widget.initialItensPorPagina,
              pagina: widget.initialPagina,
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
    final mode = ref.read(libraryCatalogModeProvider);
    final viewSettings = ref.read(libraryViewSettingsProvider);

    final String target;
    if (mode == LibraryCatalogMode.coldigom) {
      final coldigom = ref.read(coldigomLibraryFiltersProvider);
      target = buildLibraryLocation(
        fonte: mode.urlValue,
        tonality: coldigom.tonalityUrlValue,
        rhythm: coldigom.rhythmUrlValue,
        category: coldigom.categoryUrlValue,
        tags: coldigom.tagsUrlValue,
        materialKinds: coldigom.materialKindsUrlValue,
        ordenar: viewSettings.ordenarUrlValue ?? viewSettings.sortBy,
        itensPorPagina:
            viewSettings.itensPorPaginaUrlValue ??
            '${viewSettings.itemsPerPage}',
        pagina: viewSettings.paginaUrlValue ?? '${viewSettings.page}',
      );
    } else {
      final filters = ref.read(catalogFiltersProvider);
      final special = ref.read(librarySpecialArrangementProvider);
      target = buildLibraryLocation(
        materiais: filters.materiaisUrlValue,
        arranjo: filters.arranjoUrlValue,
        arranjoEspecial: special.arranjoEspecialUrlValue,
        ordenar: viewSettings.ordenarUrlValue ?? viewSettings.sortBy,
        itensPorPagina:
            viewSettings.itensPorPaginaUrlValue ??
            '${viewSettings.itemsPerPage}',
        pagina: viewSettings.paginaUrlValue ?? '${viewSettings.page}',
      );
    }

    if (buildLibraryLocationFromUri(uri) == target) return;
    goRouter.go(target);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(libraryCatalogModeProvider);
    final isColdigom = mode == LibraryCatalogMode.coldigom;
    final results = ref.watch(libraryGroupResultsProvider);
    final manifestAsync = ref.watch(louvoresManifestProvider);
    final coldigomAsync = ref.watch(libraryColdigomBrowseProvider);

    ref.listen<LibraryCatalogMode>(libraryCatalogModeProvider, (_, _) {
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });

    ref.listen<CatalogFilterState>(catalogFiltersProvider, (_, _) {
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });

    ref.listen<LibrarySpecialArrangementState>(
      librarySpecialArrangementProvider,
      (_, _) {
        if (!_urlSyncEnabled) return;
        _syncUrlFromState();
      },
    );

    ref.listen<ColdigomLibraryFilterState>(coldigomLibraryFiltersProvider, (
      _,
      _,
    ) {
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

    final hasInitialFilters = isColdigom
        ? (widget.initialTonality != null ||
              widget.initialRhythm != null ||
              widget.initialCategory != null ||
              widget.initialTags != null ||
              widget.initialMaterialKinds != null)
        : (widget.initialMateriais != null ||
              widget.initialArranjo != null ||
              widget.initialArranjoEspecial != null);

    final horizontalPadding = MediaQuery.sizeOf(context).width > 600
        ? 24.0
        : 16.0;

    final showLoading = isColdigom
        ? coldigomAsync.isLoading
        : manifestAsync.isLoading;
    final errorText = isColdigom
        ? (coldigomAsync.hasError ? l10n.coldigomLoadError : null)
        : (manifestAsync.hasError ? l10n.catalogLoadError : null);

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
                      const LibraryCatalogModeToggle(),
                      const SizedBox(height: 12),
                      FiltersPanel(
                        key: ValueKey(mode),
                        initiallyExpanded: hasInitialFilters,
                        showPlpcgSections: !isColdigom,
                        additionalExpandedSections: [
                          if (isColdigom)
                            const ColdigomLibraryFilters()
                          else
                            const SpecialArrangementFilters(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const LibraryViewControls(),
                      if (errorText != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          errorText,
                          style: AppTypography.body.copyWith(
                            color: AppColors.offlineMissing,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (showLoading)
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
