import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/constants/catalog_materials.dart';
import '../providers/catalog_filters_provider.dart';

/// UC-02 — Filtros de material (Partitura, Cifra, Gestos em Gravura).
///
/// Lê/escreve [catalogFiltersProvider.selectedMaterials]. "Cifra" expande
/// níveis I/II apenas no use case [FilterByMaterialAndArranjo].
class CategoryFilters extends ConsumerWidget {
  const CategoryFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(catalogFiltersProvider.select(
      (state) => state.selectedMaterials,
    ));

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final material in CatalogMaterials.uiMaterials)
          FilterChip(
            label: Text(
              material,
              style: AppTypography.label.copyWith(
                color: selected.contains(material)
                    ? AppColors.title
                    : AppColors.title,
              ),
            ),
            selected: selected.contains(material),
            showCheckmark: false,
            selectedColor: AppColors.gold.withValues(alpha: 0.3),
            backgroundColor: AppColors.card,
            side: BorderSide(
              color: selected.contains(material)
                  ? AppColors.gold
                  : AppColors.title,
              width: selected.contains(material) ? 2 : 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            onSelected: (_) {
              ref
                  .read(catalogFiltersProvider.notifier)
                  .toggleMaterial(material);
            },
          ),
      ],
    );
  }
}
