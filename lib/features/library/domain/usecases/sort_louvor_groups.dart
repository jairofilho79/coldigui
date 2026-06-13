import '../../../catalog/domain/entities/louvor_group.dart';

/// UC-03 — Ordenar grupos por número ou nome.
class SortLouvorGroups {
  const SortLouvorGroups();

  List<LouvorGroup> call(List<LouvorGroup> groups, {required String sortBy}) {
    final sorted = List<LouvorGroup>.from(groups);
    sorted.sort((a, b) {
      if (sortBy == 'nome') {
        return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      }
      final na = a.numeroSortKey;
      final nb = b.numeroSortKey;
      if (na != -1 && nb != -1 && na != nb) return na.compareTo(nb);
      if (na != -1 && nb == -1) return -1;
      if (na == -1 && nb != -1) return 1;
      return a.groupId.compareTo(b.groupId);
    });
    return sorted;
  }
}
