import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/usecases/filter_by_material_and_arranjo.dart';
import '../../../catalog/domain/usecases/filter_by_special_arrangement.dart';

/// UC-03 — Navegar biblioteca completa (Fase 1.4).
///
/// Lista filtrada do manifest — reutiliza filtros UC-02 + arranjo especial
/// sem exigir texto de busca.
class BrowseLibrary {
  const BrowseLibrary({
    this.filterByMaterialAndArranjo = const FilterByMaterialAndArranjo(),
    this.filterBySpecialArrangement = const FilterBySpecialArrangement(),
  });

  final FilterByMaterialAndArranjo filterByMaterialAndArranjo;
  final FilterBySpecialArrangement filterBySpecialArrangement;

  /// Retorna louvores após filtros material/arranjo (UC-02) e especial (UC-03).
  List<Louvor> call(
    List<Louvor> catalog, {
    required Set<String> selectedMaterials,
    required Set<String> selectedArranjos,
    required Set<String> selectedSpecialArrangements,
  }) {
    final byMaterialAndArranjo = filterByMaterialAndArranjo(
      catalog,
      selectedMaterials: selectedMaterials,
      selectedArranjos: selectedArranjos,
    );

    return filterBySpecialArrangement(
      byMaterialAndArranjo,
      selectedSpecialArrangements: selectedSpecialArrangements,
    );
  }
}
