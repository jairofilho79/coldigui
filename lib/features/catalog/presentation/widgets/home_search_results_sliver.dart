import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_coldigom_pagination_controls.dart';
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
    final coldigomLoading = ref.watch(homeSearchColdigomLoadingProvider);
    final page = ref.watch(homeSearchColdigomPageProvider);
    final hasNext = ref.watch(homeSearchColdigomHasNextProvider);
    final coldigomCount = ref
        .watch(homeSearchColdigomGroupsDataProvider)
        .length;

    final showPager =
        !coldigomLoading && (page > 1 || hasNext || coldigomCount > 0);
    final trailingCount = (coldigomLoading ? 1 : 0) + (showPager ? 1 : 0);

    if (results.isEmpty && trailingCount == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < results.length) {
          return LouvorGroupCard(group: results[index]);
        }
        var trailingIndex = index - results.length;
        if (coldigomLoading) {
          if (trailingIndex == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                ),
              ),
            );
          }
          trailingIndex -= 1;
        }
        if (showPager && trailingIndex == 0) {
          return const HomeColdigomPaginationControls();
        }
        return const SizedBox.shrink();
      }, childCount: results.length + trailingCount),
    );
  }
}
