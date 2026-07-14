import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/constants/catalog_materials.dart';
import '../../domain/utils/louvor_classification.dart';
import 'louvores_manifest_provider.dart';

/// Estado dos filtros UC-02 (material + arranjo).
///
/// Consumido por [catalogFiltersProvider]. Valores URL via [materiaisUrlValue]
/// e [arranjoUrlValue] — omitidos quando equivalentes ao padrão.
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

/// Filtros de material e arranjo — UC-02.
final catalogFiltersProvider =
    NotifierProvider<CatalogFiltersNotifier, CatalogFilterState>(
      CatalogFiltersNotifier.new,
    );

/// Classificações base disponíveis no manifest (chips de arranjo).
final catalogAvailableArranjosProvider = Provider<Set<String>>((ref) {
  return ref.watch(louvoresManifestProvider).value?.availableArranjos ??
      const {};
});

/// Gerencia seleção de materiais/arranjos e hidratação da URL.
class CatalogFiltersNotifier extends Notifier<CatalogFilterState> {
  @override
  CatalogFilterState build() => CatalogFilterState.defaults();

  /// Hidrata filtros a partir de query params da rota Home.
  void hydrateFromUrl({String? materiais, String? arranjo}) {
    state = CatalogFilterState(
      selectedMaterials: CatalogMaterials.parseFromUrl(materiais),
      selectedArranjos: LouvorClassification.parseArranjosFromUrl(arranjo),
    );
  }

  /// Restaura seleção padrão (todos materiais, nenhum arranjo).
  void reset() {
    state = CatalogFilterState.defaults();
  }

  /// Alterna material; impede desmarcar o último chip restante.
  void toggleMaterial(String material) {
    final current = Set<String>.from(state.selectedMaterials);
    if (current.contains(material)) {
      if (current.length <= 1) return;
      current.remove(material);
    } else {
      current.add(material);
    }
    state = state.copyWith(selectedMaterials: current);
  }

  /// Alterna arranjo (classificação base do manifest).
  void toggleArranjo(String arranjo) {
    final current = Set<String>.from(state.selectedArranjos);
    if (current.contains(arranjo)) {
      current.remove(arranjo);
    } else {
      current.add(arranjo);
    }
    state = state.copyWith(selectedArranjos: current);
  }
}
