import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../data/providers/library_providers.dart';
import '../../domain/entities/paginated_louvor_groups.dart';
import 'library_view_settings_provider.dart';

/// Grupos da /biblioteca já ordenados: índice local do catálogo → ordenar
/// (`numero`/`nome`, a regra de [SortLouvorGroups]) — spec fim-fonte §2.3.
///
/// Síncrono, sem `compute`: são ~2063 grupos já montados na hidratação e
/// ordená-los custa poucos milissegundos; na web o `compute` corre na mesma
/// thread e, no nativo, copiar os grupos para o isolate custaria mais do que
/// o trabalho (plano, Desvio 1). Separado da paginação: trocar de página não
/// reordena.
final libraryFilteredGroupsProvider = Provider<List<LouvorGroup>>((ref) {
  final groups = ref.watch(coldigomSearchIndexProvider).groups;
  final sortBy = ref.watch(
    libraryViewSettingsProvider.select((view) => view.sortBy),
  );
  return ref.watch(sortLouvorGroupsProvider)(groups, sortBy: sortBy);
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
