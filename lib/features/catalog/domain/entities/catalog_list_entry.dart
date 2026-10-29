import 'louvor_group.dart';

/// Um item da lista da Home e da /biblioteca (spec louvores-agrupados §4.1):
/// um chip solto ou um amendoim. É a unidade da paginação da /biblioteca; a
/// unidade do app (playlist, `?p=`, «+») continua sendo o praise.
sealed class CatalogListEntry {
  const CatalogListEntry();
}

/// Praise fora de grupo — ou num grupo que só tem ele na lista — como hoje.
final class SingleEntry extends CatalogListEntry {
  const SingleEntry(this.group);

  final LouvorGroup group;
}

/// Grupo do coldigom (`praises.group_id`) com ≥ 2 membros, na ordem fixa
/// (`compareClusterMembers`).
final class ClusterEntry extends CatalogListEntry {
  const ClusterEntry({required this.praiseGroupId, required this.members});

  /// Chave opaca do grupo — nunca um id de praise.
  final String praiseGroupId;
  final List<ClusterMember> members;
}

/// Um gomo do amendoim. [matched] `false` = não casou com a busca ou os
/// filtros e aparece esmaecido, mas clicável (D3).
final class ClusterMember {
  const ClusterMember({required this.group, required this.matched});

  final LouvorGroup group;
  final bool matched;
}
