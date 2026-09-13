import '../constants/catalog_materials.dart';
import '../utils/louvor_classification.dart';

/// Estado dos filtros UC-02 (material + arranjo).
///
/// Objeto de valor puro (sem Riverpod): faz parte de `CatalogQuery`, por isso
/// mora no domínio; a presentation o observa via `catalogFiltersProvider`.
/// Valores URL via [materiaisUrlValue] e [arranjoUrlValue] — omitidos quando
/// equivalentes ao padrão.
class CatalogFilterState {
  const CatalogFilterState({
    required this.selectedMaterials,
    required this.selectedArranjos,
  });

  /// Materiais UI selecionados (subset de [CatalogMaterials.uiMaterials]).
  final Set<String> selectedMaterials;

  /// Classificações base selecionadas; vazio = sem filtro de arranjo.
  final Set<String> selectedArranjos;

  /// Estado inicial: todos os materiais, nenhum arranjo filtrado.
  factory CatalogFilterState.defaults() => CatalogFilterState(
    selectedMaterials: Set<String>.from(CatalogMaterials.defaultSelected),
    selectedArranjos: {},
  );

  CatalogFilterState copyWith({
    Set<String>? selectedMaterials,
    Set<String>? selectedArranjos,
  }) {
    return CatalogFilterState(
      selectedMaterials: selectedMaterials ?? this.selectedMaterials,
      selectedArranjos: selectedArranjos ?? this.selectedArranjos,
    );
  }

  /// Valores serializáveis para URL (omitir quando padrão).
  String? get materiaisUrlValue =>
      CatalogMaterials.serializeForUrl(selectedMaterials);

  String? get arranjoUrlValue =>
      LouvorClassification.serializeArranjosForUrl(selectedArranjos);
}
