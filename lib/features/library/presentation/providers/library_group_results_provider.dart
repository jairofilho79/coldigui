import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/data/providers/catalog_providers.dart';
import '../../../catalog/presentation/providers/catalog_filters_provider.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../data/providers/library_providers.dart';
import '../../domain/entities/paginated_louvor_groups.dart';
import 'library_special_arrangement_provider.dart';
import 'library_view_settings_provider.dart';

/// Pipeline UC-03 agrupado: manifest → BrowseLibrary → Group → Sort → Paginate.
final libraryGroupResultsProvider = Provider<PaginatedLouvorGroups>((ref) {
  final filters = ref.watch(catalogFiltersProvider);
  final special = ref.watch(librarySpecialArrangementProvider);
  final viewSettings = ref.watch(libraryViewSettingsProvider);
  final manifestAsync = ref.watch(louvoresManifestProvider);
  final browse = ref.watch(browseLibraryProvider);
  final group = ref.watch(groupLouvoresByMaterialProvider);
  final sort = ref.watch(sortLouvorGroupsProvider);
  final paginate = ref.watch(paginateLouvorGroupsProvider);

  return manifestAsync.when(
    skipLoadingOnReload: true,
    data: (catalog) {
      final filtered = browse(
        catalog,
        selectedMaterials: filters.selectedMaterials,
        selectedArranjos: filters.selectedArranjos,
        selectedSpecialArrangements: special.selectedSpecialArrangements,
      );
      final grouped = group(filtered);
      final sorted = sort(grouped, sortBy: viewSettings.sortBy);
      return paginate(
        sorted,
        page: viewSettings.page,
        itemsPerPage: viewSettings.itemsPerPage,
      );
    },
    loading: () => PaginatedLouvorGroups.empty,
    error: (_, __) => PaginatedLouvorGroups.empty,
  );
});
