import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/usecases/group_louvores_by_material.dart';
import '../../domain/usecases/browse_library.dart';
import '../../domain/usecases/sort_louvor_groups.dart';

/// Entrada serializável para o pipeline UC-03 (Browse → Group → Sort) no isolate.
class LibraryGroupPipelineInput {
  const LibraryGroupPipelineInput({
    required this.catalog,
    required this.selectedMaterials,
    required this.selectedArranjos,
    required this.selectedSpecialArrangements,
    required this.sortBy,
  });

  final List<Louvor> catalog;
  final Set<String> selectedMaterials;
  final Set<String> selectedArranjos;
  final Set<String> selectedSpecialArrangements;
  final String sortBy;
}

/// Pipeline pesado da Biblioteca — executado fora do main thread via [compute].
List<LouvorGroup> runLibraryGroupPipeline(LibraryGroupPipelineInput input) {
  const browse = BrowseLibrary();
  const group = GroupLouvoresByMaterial();
  const sort = SortLouvorGroups();

  final filtered = browse(
    input.catalog,
    selectedMaterials: input.selectedMaterials,
    selectedArranjos: input.selectedArranjos,
    selectedSpecialArrangements: input.selectedSpecialArrangements,
  );
  final grouped = group(filtered);
  return sort(grouped, sortBy: input.sortBy);
}

/// Executa [runLibraryGroupPipeline] — padrão via `compute`, injetável em testes.
typedef LibraryGroupPipelineExecutor = Future<List<LouvorGroup>> Function(
  LibraryGroupPipelineInput input,
);
