import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/constants/catalog_materials.dart';
import '../../domain/entities/catalog_filter_state.dart';
import '../../domain/utils/louvor_classification.dart';
import 'louvores_manifest_provider.dart';

// O objeto de valor mudou para o domínio (D.7: `CatalogQuery` o carrega);
// quem importava daqui continua enxergando a classe.
export '../../domain/entities/catalog_filter_state.dart';

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
