import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../coldigom/domain/repositories/coldigom_search_repository.dart';
import '../../domain/entities/library_catalog_mode.dart';
import '../../domain/entities/paginated_louvor_groups.dart';
import 'coldigom_library_filters_provider.dart';
import 'library_catalog_mode_provider.dart';
import 'library_view_settings_provider.dart';

/// Browse remoto Coldigom da biblioteca (página + filtros no servidor).
final libraryColdigomBrowseProvider =
    AsyncNotifierProvider<LibraryColdigomBrowseNotifier, PaginatedLouvorGroups>(
      LibraryColdigomBrowseNotifier.new,
    );

class LibraryColdigomBrowseNotifier
    extends AsyncNotifier<PaginatedLouvorGroups> {
  @override
  Future<PaginatedLouvorGroups> build() async {
    final mode = ref.watch(libraryCatalogModeProvider);
    if (mode != LibraryCatalogMode.coldigom) {
      return PaginatedLouvorGroups.empty;
    }

    final filters = ref.watch(coldigomLibraryFiltersProvider);
    final view = ref.watch(libraryViewSettingsProvider);
    final repo = ref.watch(coldigomSearchRepositoryProvider);

    final result = await repo.browse(
      ColdigomBrowseQuery(
        tonalities: filters.selectedTonalities,
        rhythms: filters.selectedRhythms,
        categories: filters.selectedCategories,
        tagIds: filters.selectedTagIds,
        materialKindIds: filters.selectedMaterialKindIds,
        page: view.page,
        limit: view.itemsPerPage,
        sortBy: view.sortBy,
      ),
    );

    ref
        .read(coldigomLouvoresCacheProvider.notifier)
        .mergeLouvores(result.louvores);

    return PaginatedLouvorGroups(
      items: result.groups,
      page: result.page,
      itemsPerPage: result.limit,
      totalItems: result.totalItems,
      totalPages: result.totalPages,
    );
  }
}
