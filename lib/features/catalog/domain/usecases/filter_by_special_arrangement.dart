import '../entities/louvor.dart';
import '../utils/louvor_classification.dart';

/// UC-03 — Filtrar por arranjo especial (texto entre parênteses).
///
/// [selectedSpecialArrangements] vazio → todos passam. Caso contrário,
/// [LouvorClassification.specialArrangement] deve pertencer à seleção.
class FilterBySpecialArrangement {
  const FilterBySpecialArrangement();

  /// Filtra [louvores] pelos arranjos especiais selecionados.
  List<Louvor> call(
    List<Louvor> louvores, {
    required Set<String> selectedSpecialArrangements,
  }) {
    if (selectedSpecialArrangements.isEmpty) {
      return List<Louvor>.from(louvores);
    }

    return louvores
        .where(
          (louvor) => selectedSpecialArrangements.contains(
            LouvorClassification.specialArrangement(louvor.classificacao),
          ),
        )
        .toList(growable: false);
  }
}
