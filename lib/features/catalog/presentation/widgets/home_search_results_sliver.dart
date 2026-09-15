import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_empty_state.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_freshness_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lista de resultados da Home — isolada da [SearchBar] para evitar rebuilds
/// do campo de busca quando a validação remota conclui.
///
/// Desde a pesquisa híbrida (§6) a lista é a local; o remoto só acrescenta
/// «novos» no fim e alimenta a [SearchFreshnessLine] no topo. Não há mais
/// spinner de rodapé, pager nem linha «Coldigom indisponível»: os três
/// viraram estados da linha.
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

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) return line;
        final group = results[index - 1];
        return LouvorGroupCard(
          key: ValueKey('card-${group.groupId}'),
          group: group,
          isNew: newIds.contains(group.groupId),
        );
      }, childCount: results.length + 1),
    );
  }
}
