import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../catalog/domain/entities/louvor_group.dart';

/// UC-03 — Ordenar grupos por número ou nome.
///
/// O nome compara normalizado ([LouvorSearchTokens.normalize]: minúsculas e
/// sem acento), para «Éden» ficar entre «alfa» e «Ester». Por número, os sem
/// número vão para o fim ordenados pelo nome; o `groupId` só desempata nomes
/// iguais, para a ordem ser estável.
class SortLouvorGroups {
  const SortLouvorGroups();

  List<LouvorGroup> call(List<LouvorGroup> groups, {required String sortBy}) {
    final keyed = [
      for (final group in groups)
        (group: group, name: LouvorSearchTokens.normalize(group.nome)),
    ];
    keyed.sort((a, b) {
      if (sortBy != 'nome') {
        final na = a.group.numeroSortKey;
        final nb = b.group.numeroSortKey;
        if (na != -1 && nb != -1 && na != nb) return na.compareTo(nb);
        if (na != -1 && nb == -1) return -1;
        if (na == -1 && nb != -1) return 1;
      }
      final byName = a.name.compareTo(b.name);
      if (byName != 0) return byName;
      return a.group.groupId.compareTo(b.group.groupId);
    });
    return [for (final entry in keyed) entry.group];
  }
}
