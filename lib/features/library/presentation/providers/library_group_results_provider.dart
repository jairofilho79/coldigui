import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/usecases/matches_catalog_filters.dart';
import '../../../catalog/presentation/providers/catalog_filters_provider.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../data/providers/library_providers.dart';
import '../../domain/entities/paginated_louvor_groups.dart';
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
  final filters = ref.watch(catalogFiltersProvider);
  final sortBy = ref.watch(
    libraryViewSettingsProvider.select((view) => view.sortBy),
  );
  final filtered = filters.isEmpty
      ? groups
      : [
          for (final group in groups)
            if (matchesCatalogFilters(group, filters)) group,
        ];
  return ref.watch(sortLouvorGroupsProvider)(filtered, sortBy: sortBy);
});

/// Página corrente da /biblioteca — [libraryFilteredGroupsProvider] paginado.
final libraryGroupResultsProvider = Provider<PaginatedLouvorGroups>((ref) {
  final groups = ref.watch(libraryFilteredGroupsProvider);
  final view = ref.watch(libraryViewSettingsProvider);
  return ref.watch(paginateLouvorGroupsProvider)(
    groups,
    page: view.page,
    itemsPerPage: view.itemsPerPage,
  );
});
