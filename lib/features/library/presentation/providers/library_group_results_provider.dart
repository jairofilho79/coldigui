import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/presentation/providers/catalog_filters_provider.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../data/providers/library_providers.dart';
import '../../domain/entities/paginated_louvor_groups.dart';
import 'library_group_worker.dart';
import 'library_special_arrangement_provider.dart';
import 'library_view_settings_provider.dart';

/// Grupos ordenados após Browse → Group → Sort — atualizado pelo pipeline assíncrono.
final libraryGroupSortedResultsDataProvider =
    StateProvider<List<LouvorGroup>>((ref) => const []);

/// Executa o pipeline fora do main thread. Sobrescrever em testes se necessário.
final libraryGroupPipelineExecutorProvider =
    Provider<LibraryGroupPipelineExecutor>((ref) {
  return (input) => compute(runLibraryGroupPipeline, input);
});

/// Dispara Browse → Group → Sort fora do main thread.
final libraryGroupPipelineDriverProvider =
    NotifierProvider<LibraryGroupPipelineDriver, int>(
  LibraryGroupPipelineDriver.new,
);

/// Pipeline UC-03 agrupado: manifest → Browse → Group → Sort (off-thread) → Paginate.
///
/// Paginação permanece síncrona sobre [libraryGroupSortedResultsDataProvider]
/// para evitar reprocessar ~4600 louvores ao mudar apenas a página.
final libraryGroupResultsProvider = Provider<PaginatedLouvorGroups>((ref) {
  ref.watch(libraryGroupPipelineDriverProvider);
  final sortedGroups = ref.watch(libraryGroupSortedResultsDataProvider);
  final viewSettings = ref.watch(libraryViewSettingsProvider);
  final manifestAsync = ref.watch(louvoresManifestProvider);
  final paginate = ref.watch(paginateLouvorGroupsProvider);

  if (manifestAsync.hasError) {
    return PaginatedLouvorGroups.empty;
  }

  return paginate(
    sortedGroups,
    page: viewSettings.page,
    itemsPerPage: viewSettings.itemsPerPage,
  );
});

/// Executa o pipeline da Biblioteca fora do main thread; descarta resultados obsoletos.
class LibraryGroupPipelineDriver extends Notifier<int> {
  int _generation = 0;

  @override
  int build() {
    ref.listen<CatalogFilterState>(
      catalogFiltersProvider,
      (_, __) => _schedulePipeline(),
    );
    ref.listen<LibrarySpecialArrangementState>(
      librarySpecialArrangementProvider,
      (_, __) => _schedulePipeline(),
    );
    ref.listen<LibraryViewSettings>(
      libraryViewSettingsProvider,
      (previous, next) {
        if (previous?.sortBy != next.sortBy) {
          _schedulePipeline();
        }
      },
    );
    ref.listen<AsyncValue<List<Louvor>>>(
      louvoresManifestProvider,
      (_, __) => _schedulePipeline(),
      fireImmediately: true,
    );

    return 0;
  }

  void _schedulePipeline() {
    Future.microtask(() => unawaited(_runPipeline()));
  }

  Future<void> _runPipeline() async {
    final manifestAsync = ref.read(louvoresManifestProvider);

    if (manifestAsync.hasError) {
      _generation++;
      ref.read(libraryGroupSortedResultsDataProvider.notifier).state = const [];
      return;
    }

    final catalog = manifestAsync.value;
    if (catalog == null) {
      return;
    }

    final filters = ref.read(catalogFiltersProvider);
    final special = ref.read(librarySpecialArrangementProvider);
    final sortBy = ref.read(libraryViewSettingsProvider).sortBy;
    final generation = ++_generation;

    final input = LibraryGroupPipelineInput(
      catalog: List.of(catalog),
      selectedMaterials: filters.selectedMaterials,
      selectedArranjos: filters.selectedArranjos,
      selectedSpecialArrangements: special.selectedSpecialArrangements,
      sortBy: sortBy,
    );

    final execute = ref.read(libraryGroupPipelineExecutorProvider);
    final groups = await execute(input);

    if (generation != _generation) return;

    ref.read(libraryGroupSortedResultsDataProvider.notifier).state = groups;
  }
}
