import '../entities/catalog_list_entry.dart';
import '../entities/louvor_group.dart';
import 'cluster_member_order.dart';

/// Junta os grupos do coldigom da lista [ordered] em amendoins (spec
/// louvores-agrupados §4.2). [ordered] é a lista já filtrada e ordenada — os
/// que casaram.
///
/// - Membros de um grupo = [membersOf] ∪ [extraMembers] do mesmo
///   `group_id`, sem repetir praiseId, na ordem fixa. [extraMembers] são os
///   que o índice não tem (os «novos» da busca remota).
/// - Instância de cada membro: a de [ordered] se ele casou (a do remoto traz
///   o trecho da letra); senão a do índice; senão a de [extraMembers].
/// - O amendoim sai na posição do primeiro membro em [ordered], com **todos**
///   os membros; as aparições seguintes são puladas.
/// - Grupo que fica com 1 membro depois da soma vira [SingleEntry]; grupo
///   sem membro em [ordered] não aparece.
List<CatalogListEntry> clusterCatalogList(
  List<LouvorGroup> ordered, {
  required List<LouvorGroup> Function(String praiseGroupId) membersOf,
  Iterable<LouvorGroup> extraMembers = const [],
}) {
  final orderedById = <String, LouvorGroup>{
    for (final group in ordered) group.groupId: group,
  };
  final extrasByKey = <String, List<LouvorGroup>>{};
  for (final group in extraMembers) {
    final key = praiseGroupKeyOf(group);
    if (key != null) extrasByKey.putIfAbsent(key, () => []).add(group);
  }

  final clustered = <String>{};
  final entries = <CatalogListEntry>[];
  for (final group in ordered) {
    final key = praiseGroupKeyOf(group);
    if (key == null) {
      entries.add(SingleEntry(group));
      continue;
    }
    if (clustered.contains(key)) continue;

    final byId = <String, LouvorGroup>{};
    for (final member in membersOf(key)) {
      byId.putIfAbsent(member.groupId, () => member);
    }
    for (final member in extrasByKey[key] ?? const <LouvorGroup>[]) {
      byId.putIfAbsent(member.groupId, () => member);
    }
    byId[group.groupId] = group;
    if (byId.length < 2) {
      entries.add(SingleEntry(group));
      continue;
    }

    clustered.add(key);
    final members = [
      for (final member in byId.values) orderedById[member.groupId] ?? member,
    ]..sort(compareClusterMembers);
    entries.add(
      ClusterEntry(
        praiseGroupId: key,
        members: [
          for (final member in members)
            ClusterMember(
              group: member,
              matched: orderedById.containsKey(member.groupId),
            ),
        ],
      ),
    );
  }
  return entries;
}
