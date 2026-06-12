import '../constants/catalog_materials.dart';
import '../entities/louvor.dart';
import '../utils/louvor_classification.dart';

/// UC-02 — Filtrar por material e arranjo.
///
/// Filtro in-memory síncrono: material via [Louvor.categoria] com expansão
/// de "Cifra"; arranjo via classificação base de [Louvor.classificacao].
/// [selectedArranjos] vazio → sem filtro de arranjo.
class FilterByMaterialAndArranjo {
  const FilterByMaterialAndArranjo();

  /// Filtra [louvores] pelos materiais e arranjos selecionados.
  ///
  /// [selectedMaterials] vazio → `[]`. [selectedArranjos] vazio → todos os
  /// arranjos passam. Material "Cifra" inclui [CatalogMaterials.cifraNivelI]
  /// e [CatalogMaterials.cifraNivelII].
  List<Louvor> call(
    List<Louvor> louvores, {
    required Set<String> selectedMaterials,
    required Set<String> selectedArranjos,
  }) {
    if (selectedMaterials.isEmpty) return const [];

    final expandedMaterials =
        CatalogMaterials.expandMaterials(selectedMaterials);

    return louvores.where((louvor) {
      if (!expandedMaterials.contains(louvor.categoria)) return false;
      if (selectedArranjos.isEmpty) return true;

      return selectedArranjos.contains(
        LouvorClassification.baseClassification(louvor.classificacao),
      );
    }).toList(growable: false);
  }
}
