import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/utils/louvor_classification.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';

/// Estado do filtro de arranjo especial (UC-03) — exclusivo da biblioteca.
class LibrarySpecialArrangementState {
  const LibrarySpecialArrangementState({
    required this.selectedSpecialArrangements,
  });

  /// Arranjos especiais selecionados; vazio = sem filtro (todos).
  final Set<String> selectedSpecialArrangements;

  factory LibrarySpecialArrangementState.empty() =>
      const LibrarySpecialArrangementState(selectedSpecialArrangements: {});

  LibrarySpecialArrangementState copyWith({
    Set<String>? selectedSpecialArrangements,
  }) {
    return LibrarySpecialArrangementState(
      selectedSpecialArrangements:
          selectedSpecialArrangements ?? this.selectedSpecialArrangements,
    );
  }

  /// Valor serializável para URL `arranjoEspecial=`; vazio → omitir.
  String? get arranjoEspecialUrlValue =>
      LouvorClassification.serializeSpecialArrangementsForUrl(
        selectedSpecialArrangements,
      );
}

/// Filtro de arranjo especial — UC-03.
final librarySpecialArrangementProvider = NotifierProvider<
    LibrarySpecialArrangementNotifier, LibrarySpecialArrangementState>(
  LibrarySpecialArrangementNotifier.new,
);

/// Arranjos especiais únicos do manifest (inclui [LouvorClassification.specialArrangementPadrao]).
final libraryAvailableSpecialArrangementsProvider =
    Provider<Set<String>>((ref) {
  final catalog = ref.watch(louvoresManifestProvider).value?.louvores;
  if (catalog == null) return const {};
  return catalog
      .map((l) => LouvorClassification.specialArrangement(l.classificacao))
      .toSet();
});

/// Gerencia seleção e hidratação de `arranjoEspecial=` na URL.
class LibrarySpecialArrangementNotifier
    extends Notifier<LibrarySpecialArrangementState> {
  @override
  LibrarySpecialArrangementState build() =>
      LibrarySpecialArrangementState.empty();

  void hydrateFromUrl({String? arranjoEspecial}) {
    state = LibrarySpecialArrangementState(
      selectedSpecialArrangements:
          LouvorClassification.parseSpecialArrangementsFromUrl(
        arranjoEspecial,
      ),
    );
  }

  void toggleSpecialArrangement(String arrangement) {
    final current = Set<String>.from(state.selectedSpecialArrangements);
    if (current.contains(arrangement)) {
      current.remove(arrangement);
    } else {
      current.add(arrangement);
    }
    state = state.copyWith(selectedSpecialArrangements: current);
  }
}
