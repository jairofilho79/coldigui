import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
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

/// Gerencia seleção de materiais/arranjos, persistência (C13) e hidratação
/// da URL.
class CatalogFiltersNotifier extends Notifier<CatalogFilterState> {
  @override
  CatalogFilterState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(StorageKeys.catalogFilters);
    if (raw == null || raw.isEmpty) return CatalogFilterState.defaults();

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final materials = ((decoded['materials'] as List?) ?? const [])
          .whereType<String>()
          .toSet();
      final arranjos = ((decoded['arranjos'] as List?) ?? const [])
          .whereType<String>()
          .toSet();
      if (materials.isEmpty) return CatalogFilterState.defaults();
      return CatalogFilterState(
        selectedMaterials: materials,
        selectedArranjos: arranjos,
      );
    } on Object catch (e) {
      AppLogger.of(
        'catalog',
      ).warn('Filtros persistidos inválidos, usando default', e);
      return CatalogFilterState.defaults();
    }
  }

  Future<void> _persist(CatalogFilterState value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      StorageKeys.catalogFilters,
      jsonEncode({
        'materials': value.selectedMaterials.toList(),
        'arranjos': value.selectedArranjos.toList(),
      }),
    );
  }

  /// Hidrata filtros a partir de query params da rota Home/Biblioteca.
  ///
  /// Chamado incondicionalmente no primeiro build das telas (mesmo sem
  /// query params) — sem [materiais] nem [arranjo], preserva o estado atual
  /// (persistido em [build]) em vez de resetar para o default.
  void hydrateFromUrl({String? materiais, String? arranjo}) {
    final hasMateriais = materiais != null && materiais.trim().isNotEmpty;
    final hasArranjo = arranjo != null && arranjo.trim().isNotEmpty;
    if (!hasMateriais && !hasArranjo) return;

    state = CatalogFilterState(
      selectedMaterials: hasMateriais
          ? CatalogMaterials.parseFromUrl(materiais)
          : state.selectedMaterials,
      selectedArranjos: hasArranjo
          ? LouvorClassification.parseArranjosFromUrl(arranjo)
          : state.selectedArranjos,
    );
  }

  /// Restaura seleção padrão (todos materiais, nenhum arranjo) e apaga a
  /// persistência.
  void reset() {
    state = CatalogFilterState.defaults();
    final prefs = ref.read(sharedPreferencesProvider);
    unawaited(prefs.remove(StorageKeys.catalogFilters));
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
    unawaited(_persist(state));
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
    unawaited(_persist(state));
  }
}
