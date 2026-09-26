import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart';
import 'package:coldigui/features/catalog/domain/usecases/cluster_member_label.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/peanut_cluster_column.dart';
import 'package:flutter/widgets.dart';

/// Amendoim na Home e na /biblioteca (spec louvores-agrupados §6.3): um
/// `LouvorGroupCard`-gomo por membro, colados, com a etiqueta da versão.
/// Cada gomo se comporta como o chip de hoje (D6): toque, «+», ícones,
/// offline e «novo» são daquela versão.
class LouvorClusterCard extends StatelessWidget {
  const LouvorClusterCard({
    required this.entry,
    this.newGroupIds = const {},
    super.key,
  });

  final ClusterEntry entry;

  /// Ids com o selo «novo» (`HomeSearchState.newGroupIds`); vazio na
  /// /biblioteca.
  final Set<String> newGroupIds;

  @override
  Widget build(BuildContext context) {
    final groups = [for (final member in entry.members) member.group];
    return Padding(
      // O espaço de baixo do cartão fica por fora: dentro do último gomo ele
      // entraria na altura que desenha a silhueta da sombra.
      padding: const EdgeInsets.only(bottom: 8),
      child: PeanutClusterColumn(
        children: [
          for (final (index, member) in entry.members.indexed)
            LouvorGroupCard(
              key: ValueKey(member.group.groupId),
              group: member.group,
              isNew: newGroupIds.contains(member.group.groupId),
              lobePosition: lobePositionAt(index, entry.members.length),
              groupLabel: clusterMemberLabel(member.group, groups),
              dimmed: !member.matched,
            ),
        ],
      ),
    );
  }
}
