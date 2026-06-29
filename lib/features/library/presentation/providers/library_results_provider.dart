import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/presentation/providers/catalog_filters_provider.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../data/providers/library_providers.dart';
import '../../domain/entities/paginated_louvores.dart';
import 'library_special_arrangement_provider.dart';
import 'library_view_settings_provider.dart';

/// Pipeline UC-03: manifest → BrowseLibrary → SortLouvores → PaginateLouvores.
final libraryResultsProvider = Provider<PaginatedLouvores>((ref) {
  final filters = ref.watch(catalogFiltersProvider);
  final special = ref.watch(librarySpecialArrangementProvider);
  final viewSettings = ref.watch(libraryViewSettingsProvider);
  final manifestAsync = ref.watch(louvoresManifestProvider);
  final browse = ref.watch(browseLibraryProvider);
  final sort = ref.watch(sortLouvoresProvider);
  final paginate = ref.watch(paginateLouvoresProvider);

  return manifestAsync.when(
    skipLoadingOnReload: true,
    data: (manifest) {
      final filtered = browse(
        manifest.louvores,
        selectedMaterials: filters.selectedMaterials,
        selectedArranjos: filters.selectedArranjos,
        selectedSpecialArrangements: special.selectedSpecialArrangements,
      );
      final sorted = sort(filtered, sortBy: viewSettings.sortBy);
      return paginate(
        sorted,
        page: viewSettings.page,
        itemsPerPage: viewSettings.itemsPerPage,
      );
    },
    loading: () => PaginatedLouvores.empty,
    error: (_, _) => PaginatedLouvores.empty,
  );
});
