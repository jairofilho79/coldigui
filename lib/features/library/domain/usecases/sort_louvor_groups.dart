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
      final na = int.tryParse(a.numero);
      final nb = int.tryParse(b.numero);
      if (na != null && nb != null && na != nb) return na.compareTo(nb);
      if (na != null && nb == null) return -1;
      if (na == null && nb != null) return 1;
      return a.groupId.compareTo(b.groupId);
    });
    return sorted;
  }
}
