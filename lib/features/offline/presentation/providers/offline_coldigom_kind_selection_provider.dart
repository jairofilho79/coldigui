import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/material_kind_taxonomy.dart';
import '../../../catalog/domain/utils/material_kind_selection.dart';
import '../../data/providers/offline_coldigom_providers.dart';

/// Kinds marcados para download (O11).
///
/// Enquanto o utilizador nunca decidiu, o estado é vazio e a UI mostra a
/// pré-marcação ([effectiveSelection]: favoritos ∩ kinds com material
/// baixável). O primeiro toque grava a decisão inteira em prefs — a partir
/// daí os favoritos deixam de influenciar.
final offlineColdigomKindSelectionProvider =
    NotifierProvider<OfflineColdigomKindSelectionNotifier, Set<String>>(
      OfflineColdigomKindSelectionNotifier.new,
    );

class OfflineColdigomKindSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final store = ref.read(offlineColdigomKindSelectionStoreProvider);
    return store.hasDecision ? store.read() : const {};
  }

  bool get hasDecision =>
      ref.read(offlineColdigomKindSelectionStoreProvider).hasDecision;

  Set<String> effectiveSelection({
    required List<String> favoriteKindIds,
    required Set<String> availableKindIds,
  }) {
    if (hasDecision) return state;
    return {
      for (final id in favoriteKindIds)
        if (availableKindIds.contains(id)) id,
    };
  }

  /// [currentEffective] é o que a UI mostrava (pré-marcação ou decisão): o
  /// primeiro toque transforma a pré-marcação em decisão gravada.
  /// Com [taxonomy], segue as regras de família (marcar pai inclui variantes).
  Future<void> toggle(
    String kindId, {
    required Set<String> currentEffective,
    MaterialKindTaxonomy? taxonomy,
  }) async {
    final Set<String> next;
    if (taxonomy != null && taxonomy.kinds.isNotEmpty) {
      next = toggleMaterialKindSelection(currentEffective, kindId, taxonomy);
    } else {
      final copy = {...currentEffective};
      if (!copy.remove(kindId)) copy.add(kindId);
      next = copy;
    }
    state = next;
    await ref.read(offlineColdigomKindSelectionStoreProvider).write(next);
  }

  Future<void> setSelection(Set<String> next) async {
    state = next;
    await ref.read(offlineColdigomKindSelectionStoreProvider).write(next);
  }
}
