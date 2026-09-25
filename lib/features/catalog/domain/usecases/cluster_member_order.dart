import '../../../../core/utils/louvor_search_tokens.dart';
import '../entities/louvor_group.dart';

/// Chave do grupo do coldigom a que [group] pertence (`praises.group_id`),
/// ou `null` fora de grupo. Chave opaca: nunca é um id de praise
/// (spec louvores-agrupados §1 F1).
String? praiseGroupKeyOf(LouvorGroup group) => group.coldigomMeta?.groupId;

/// Ordem fixa dos membros dentro do amendoim (spec §4.4) — independe da
/// ordenação da tela, então o mesmo grupo sai igual na Home e na /biblioteca.
///
/// Número crescente (sem número por último, como [SortLouvorGroups]) → nome
/// normalizado → menos tags (a versão-base antes do arranjo) → praiseId.
int compareClusterMembers(LouvorGroup a, LouvorGroup b) {
  final na = a.numeroSortKey;
  final nb = b.numeroSortKey;
  if (na != nb) {
    if (na == -1) return 1;
    if (nb == -1) return -1;
    return na.compareTo(nb);
  }
  final byName = LouvorSearchTokens.normalize(a.nome)
      .compareTo(LouvorSearchTokens.normalize(b.nome));
  if (byName != 0) return byName;
  final byTags = (a.coldigomMeta?.tagNames.length ?? 0).compareTo(
    b.coldigomMeta?.tagNames.length ?? 0,
  );
  if (byTags != 0) return byTags;
  return a.groupId.compareTo(b.groupId);
}
