import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/catalog_filters_provider.dart';

/// UC-02 — Filtros de arranjo/classificação (chips dinâmicos do manifest).
///
/// Opções derivadas de [catalogAvailableArranjosProvider]. Arranjo especial
/// entre parênteses (UC-03) não aparece aqui — só classificação base.
class ClassificationFilters extends ConsumerWidget {
  const ClassificationFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(catalogAvailableArranjosProvider);
    final selected = ref.watch(catalogFiltersProvider.select(
      (state) => state.selectedArranjos,
    ));

    if (available.isEmpty) return const SizedBox.shrink();

    final sorted = available.toList()..sort();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final arranjo in sorted)
          FilterChip(
            label: Text(arranjo, style: AppTypography.label),
            selected: selected.contains(arranjo),
            showCheckmark: false,
            selectedColor: AppColors.gold.withValues(alpha: 0.3),
            backgroundColor: AppColors.card,
            side: BorderSide(
              color:
                  selected.contains(arranjo) ? AppColors.gold : AppColors.title,
              width: selected.contains(arranjo) ? 2 : 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            onSelected: (_) {
              ref.read(catalogFiltersProvider.notifier).toggleArranjo(arranjo);
            },
          ),
      ],
    );
  }
}
