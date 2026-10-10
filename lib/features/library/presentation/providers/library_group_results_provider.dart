import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/catalog_list_entry.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/usecases/cluster_catalog_list.dart';
import '../../../catalog/domain/usecases/matches_catalog_filters.dart';
import '../../../catalog/domain/utils/material_kind_selection.dart';
import '../../../catalog/presentation/providers/catalog_filters_provider.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../data/providers/library_providers.dart';
import '../../domain/entities/paginated_catalog_entries.dart';
import 'library_view_settings_provider.dart';

/// Grupos da /biblioteca já filtrados e ordenados: índice local do catálogo →
/// `matchesCatalogFilters` → ordenar (`numero`/`nome`, a regra de
/// [SortLouvorGroups]) — spec fim-fonte §2.3.
///
/// Síncrono, sem `compute`: são ~2063 grupos já montados na hidratação e
/// ordená-los custa poucos milissegundos; na web o `compute` corre na mesma
/// thread e, no nativo, copiar os grupos para o isolate custaria mais do que
/// o trabalho (plano, Desvio 1). Separado da paginação: trocar de página não
/// reordena.
final libraryFilteredGroupsProvider = Provider<List<LouvorGroup>>((ref) {
  final groups = ref.watch(coldigomSearchIndexProvider).groups;
  final filters = ref.watch(libraryCatalogFiltersProvider);
  final kindTaxonomy = ref.watch(coldigomKindTaxonomyProvider);
  final sortBy = ref.watch(
    libraryViewSettingsProvider.select((view) => view.sortBy),
  );
  if (filters.isEmpty) {
    return ref.watch(sortLouvorGroupsProvider)(groups, sortBy: sortBy);
  }
  final effectiveKindIds = effectiveMaterialKindIds(
    filters.materialKindIds,
    kindTaxonomy,
  );
  final filtered = [
    for (final group in groups)
      if (matchesCatalogFilters(
        group,
        filters,
        effectiveKindIds: effectiveKindIds,
      ))
        group,
  ];
  return ref.watch(sortLouvorGroupsProvider)(filtered, sortBy: sortBy);
});

/// Entradas da /biblioteca: [libraryFilteredGroupsProvider] com os grupos
/// do coldigom juntados em amendoins — grupo inteiro, com quem não casou
/// com os filtros esmaecido (spec louvores-agrupados §4.2–4.3).
final libraryEntriesProvider = Provider<List<CatalogListEntry>>((ref) {
  final groups = ref.watch(libraryFilteredGroupsProvider);
  final index = ref.watch(coldigomSearchIndexProvider);
  return clusterCatalogList(groups, membersOf: index.membersOf);
});

/// Página corrente da /biblioteca — [libraryEntriesProvider] paginado em
/// cartões.
final libraryGroupResultsProvider = Provider<PaginatedCatalogEntries>((ref) {
  final entries = ref.watch(libraryEntriesProvider);
  final view = ref.watch(libraryViewSettingsProvider);
  return ref.watch(paginateCatalogEntriesProvider)(
    entries,
    page: view.page,
    itemsPerPage: view.itemsPerPage,
  );
});
