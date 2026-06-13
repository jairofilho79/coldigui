import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lista de resultados da Home — isolada da [SearchBar] para evitar rebuilds
/// do campo de busca quando o pipeline assíncrono conclui.
class HomeSearchResultsSliver extends ConsumerWidget {
  const HomeSearchResultsSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(homeSearchGroupResultsProvider);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => LouvorGroupCard(group: results[index]),
        childCount: results.length,
      ),
    );
  }
}
