import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Navegação Anterior / Página N / Próxima da busca coldigom na Home.
///
/// Espelha o padrão visual da biblioteca, sem seletor de itens por página.
class HomeColdigomPaginationControls extends ConsumerWidget {
  const HomeColdigomPaginationControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final page = ref.watch(homeSearchColdigomPageProvider);
    final hasNext = ref.watch(homeSearchColdigomHasNextProvider);
    final coldigomCount = ref
        .watch(homeSearchColdigomGroupsDataProvider)
        .length;
    final loading = ref.watch(homeSearchColdigomLoadingProvider);

    final showPager = !loading && (page > 1 || hasNext || coldigomCount > 0);
    if (!showPager) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: l10n.pagePrevious,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(foregroundColor: AppColors.textLight),
            onPressed: page > 1
                ? () =>
                      ref.read(homeSearchColdigomPageProvider.notifier).state =
                          page - 1
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            l10n.pageCurrent(page),
            style: AppTypography.label.copyWith(color: AppColors.textLight),
          ),
          IconButton(
            tooltip: l10n.pageNext,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(foregroundColor: AppColors.textLight),
            onPressed: hasNext
                ? () =>
                      ref.read(homeSearchColdigomPageProvider.notifier).state =
                          page + 1
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
