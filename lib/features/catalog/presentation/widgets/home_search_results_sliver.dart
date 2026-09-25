import 'package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_empty_state.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_cluster_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_freshness_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lista de resultados da Home — isolada da [SearchBar] para evitar rebuilds
/// do campo de busca quando a validação remota conclui.
///
/// Desde a pesquisa híbrida (§6) a lista é a local; o remoto acrescenta
/// extras e alimenta a [SearchFreshnessLine] no topo. A tela desenha
/// `state.entries`: um extra que é membro de um grupo já na tela entra no
/// amendoim dele, os outros vão no fim (spec louvores-agrupados §6.3). Não
/// há mais spinner de rodapé, pager nem linha «Coldigom indisponível»: os
/// três viraram estados da linha.
class HomeSearchResultsSliver extends ConsumerWidget {
  const HomeSearchResultsSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeSearchStateProvider);
    final results = state.groups;
    final newIds = state.newGroupIds;

    if (state.isEmptyQuery) {
      return SliverToBoxAdapter(child: HomeEmptyState(state: state));
    }

    final line = SearchFreshnessLine(
      freshness: state.freshness,
      newCount: state.newCount,
      onRetry: () => retryRemoteSearch(ref),
    );

    if (results.isEmpty) {
      // Enquanto o remoto valida, «Nenhum louvor» seria mentira: ele ainda
      // pode trazer algo. A linha sozinha diz o que está a acontecer.
      return SliverToBoxAdapter(
        child: Column(
          children: [
            line,
            if (!state.remoteLoading) HomeEmptyState(state: state),
          ],
        ),
      );
    }

    // Um item por entrada, não por praise: os grupos do coldigom viram um
    // amendoim só (spec louvores-agrupados §6.3).
    final entries = state.entries;
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) return line;
        return switch (entries[index - 1]) {
          SingleEntry(:final group) => LouvorGroupCard(
            key: ValueKey('card-${group.groupId}'),
            group: group,
            isNew: newIds.contains(group.groupId),
          ),
          final ClusterEntry cluster => LouvorClusterCard(
            key: ValueKey('cluster-${cluster.praiseGroupId}'),
            entry: cluster,
            newGroupIds: newIds,
          ),
        };
      }, childCount: entries.length + 1),
    );
  }
}
