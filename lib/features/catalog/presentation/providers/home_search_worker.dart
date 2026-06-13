import '../../domain/entities/louvor.dart';
import '../../domain/entities/louvor_group.dart';
import '../../domain/usecases/filter_by_material_and_arranjo.dart';
import '../../domain/usecases/group_louvores_by_material.dart';
import '../../domain/usecases/search_louvor_by_number_or_text.dart';

/// Entrada serializável para o pipeline UC-01 → UC-02 → agrupamento no isolate.
class HomeSearchPipelineInput {
  const HomeSearchPipelineInput({
    required this.catalog,
    required this.query,
    required this.selectedMaterials,
    required this.selectedArranjos,
  });

  final List<Louvor> catalog;
  final String query;
  final Set<String> selectedMaterials;
  final Set<String> selectedArranjos;
}

/// Pipeline completo da Home — executado fora do main thread via [Isolate.run].
List<LouvorGroup> runHomeSearchPipeline(HomeSearchPipelineInput input) {
  const search = SearchLouvorByNumberOrText();
  const filter = FilterByMaterialAndArranjo();
  const group = GroupLouvoresByMaterial();

  final searched = search(input.catalog, input.query);
  final filtered = filter(
    searched,
    selectedMaterials: input.selectedMaterials,
    selectedArranjos: input.selectedArranjos,
  );
  return group(filtered);
}

/// Executa [runHomeSearchPipeline] — padrão via `compute`, injetável em testes.
typedef HomeSearchPipelineExecutor = Future<List<LouvorGroup>> Function(
  HomeSearchPipelineInput input,
);
