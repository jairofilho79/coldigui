import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/material_id_kind.dart';
import '../../../catalog/domain/entities/material_kind_taxonomy.dart';
import '../../../catalog/domain/utils/material_kind_selection.dart';
import '../../data/providers/offline_coldigom_providers.dart';
import '../../domain/entities/coldigom_download_target.dart';

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
    final next = {...currentEffective};
    final isAnySelected = next.contains(kindId) ||
        next.any((s) => s.startsWith('$kindId:'));

    if (isAnySelected) {
      next.remove(kindId);
      next.removeWhere((s) => s.startsWith('$kindId:'));
      if (taxonomy != null && taxonomy.kinds.isNotEmpty) {
        for (final child in taxonomy.childrenOf(kindId)) {
          next.remove(child);
          next.removeWhere((s) => s.startsWith('$child:'));
        }
      }
    } else {
      if (taxonomy != null && taxonomy.kinds.isNotEmpty) {
        final withTaxonomy = toggleMaterialKindSelection(
          currentEffective,
          kindId,
          taxonomy,
        );
        next.addAll(withTaxonomy);
      } else {
        next.add(kindId);
      }
      next.removeWhere((s) => s.startsWith('$kindId:'));
    }

    state = next;
    await ref.read(offlineColdigomKindSelectionStoreProvider).write(next);
  }

  /// Alterna a seleção de um tipo específico [type] em [kindId].
  Future<void> toggleType(
    String kindId,
    MaterialKind type, {
    required Set<MaterialKind> availableTypes,
    required Set<String> currentEffective,
  }) async {
    final next = {...currentEffective};
    final typeKey = '$kindId:${type.name}';
    final isSelected = isOfflineTypeSelected(
      kindId: kindId,
      type: type,
      selection: currentEffective,
    );

    if (isSelected) {
      next.remove(kindId);
      next.remove(typeKey);
      for (final other in availableTypes) {
        if (other != type &&
            isOfflineTypeSelected(
              kindId: kindId,
              type: other,
              selection: currentEffective,
            )) {
          next.add('$kindId:${other.name}');
        }
      }
    } else {
      next.add(typeKey);
      final allSelected = availableTypes.every(
        (t) =>
            t == type ||
            isOfflineTypeSelected(
              kindId: kindId,
              type: t,
              selection: currentEffective,
            ),
      );
      if (allSelected) {
        next.add(kindId);
        for (final t in availableTypes) {
          next.remove('$kindId:${t.name}');
        }
      }
    }

    state = next;
    await ref.read(offlineColdigomKindSelectionStoreProvider).write(next);
  }

  Future<void> setSelection(Set<String> next) async {
    state = next;
    await ref.read(offlineColdigomKindSelectionStoreProvider).write(next);
  }
}
