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
/// - Nenhum praiseId sai duas vezes. Com o índice desatualizado, o remoto
///   pode trazer em [ordered] um praise X com grupo H enquanto o índice ainda
///   o põe em G: quem sai primeiro fica com X (o amendoim de G o puxa como
///   membro; ou X sai solto/em H e G segue sem ele) e a outra aparição é
///   pulada.
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
  final emitted = <String>{};
  final entries = <CatalogListEntry>[];
  void emitSingle(LouvorGroup group) {
    emitted.add(group.groupId);
    entries.add(SingleEntry(group));
  }

  for (final group in ordered) {
    if (emitted.contains(group.groupId)) continue;
    final key = praiseGroupKeyOf(group);
    if (key == null) {
      emitSingle(group);
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
    byId.removeWhere((id, _) => emitted.contains(id));
    if (byId.length < 2) {
      emitSingle(group);
      continue;
    }

    clustered.add(key);
    final members = [
      for (final member in byId.values) orderedById[member.groupId] ?? member,
    ]..sort(compareClusterMembers);
    emitted.addAll(byId.keys);
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
