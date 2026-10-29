import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/library/domain/usecases/paginate_louvores.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_group_results_provider.dart';
import '../providers/library_view_settings_provider.dart';
import 'library_results_summary.dart';

/// UC-03 — Resumo, itens/página e navegação da biblioteca.
///
/// Agrupa [LibraryResultsSummary] com seletor de page size (chip gold com
/// [AppLocalizations.itemsPerPageValue]) e navegação anterior/próxima.
/// Chip expõe [Semantics] e [Tooltip] via [AppLocalizations.itemsPerPage].
///
/// Layout responsivo via [LayoutBuilder]:
/// ≥480px — resumo no topo, seletor à esquerda e nav à direita; <480px —
/// resumo → seletor → nav empilhados.
///
/// Estado vazio (`totalItems == 0`): renderiza apenas [LibraryResultsSummary].
class LibraryPaginationControls extends ConsumerWidget {
  const LibraryPaginationControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final results = ref.watch(libraryGroupResultsProvider);
    final itemsPerPage = ref.watch(
      libraryViewSettingsProvider.select((state) => state.itemsPerPage),
    );

    if (results.totalItems == 0) {
      return const LibraryResultsSummary();
    }

    final pageSizeControl = Semantics(
      label: l10n.itemsPerPage,
      child: Tooltip(
        message: l10n.itemsPerPage,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.gold, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: itemsPerPage,
              isDense: true,
              style: AppTypography.label.copyWith(height: 1.2),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.title,
                size: 20,
              ),
              dropdownColor: AppColors.card,
              items: [
                for (final size in PaginateLouvores.allowedPageSizes)
                  DropdownMenuItem(
                    value: size,
                    child: Text(l10n.itemsPerPageValue(size)),
                  ),
              ],
              selectedItemBuilder: (context) => [
                for (final size in PaginateLouvores.allowedPageSizes)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(l10n.itemsPerPageValue(size)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                ref
                    .read(libraryViewSettingsProvider.notifier)
                    .setItemsPerPage(value);
              },
            ),
          ),
        ),
      ),
    );

    final pageNavigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.pagePrevious,
          visualDensity: VisualDensity.compact,
          onPressed: results.page > 1
              ? () => ref
                    .read(libraryViewSettingsProvider.notifier)
                    .goToPreviousPage()
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          l10n.pageIndicator(results.page, results.totalPages),
          style: AppTypography.label,
        ),
        IconButton(
          tooltip: l10n.pageNext,
          visualDensity: VisualDensity.compact,
          onPressed: results.page < results.totalPages
              ? () => ref
                    .read(libraryViewSettingsProvider.notifier)
                    .goToNextPage(results.totalPages)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LibraryResultsSummary(),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 480;

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: pageSizeControl,
                  ),
                  const SizedBox(height: 8),
                  Center(child: pageNavigation),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [pageSizeControl, const Spacer(), pageNavigation],
            );
          },
        ),
      ],
    );
  }
}
