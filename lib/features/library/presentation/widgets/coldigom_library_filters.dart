import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/library/presentation/providers/coldigom_library_facets_provider.dart';
import 'package:coldigui/features/library/presentation/providers/coldigom_library_filters_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filtros server-side Coldigom (tom, ritmo, categoria, tags, materiais).
class ColdigomLibraryFilters extends ConsumerWidget {
  const ColdigomLibraryFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final facetsAsync = ref.watch(coldigomLibraryFacetsProvider);
    final selected = ref.watch(coldigomLibraryFiltersProvider);
    final notifier = ref.read(coldigomLibraryFiltersProvider.notifier);

    return facetsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => Text(
        l10n.coldigomLoadError,
        style: AppTypography.body.copyWith(color: AppColors.offlineMissing),
      ),
      data: (facets) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipSection(
            title: l10n.coldigomFilterTonality,
            values: facets.options.tonalities,
            selected: selected.selectedTonalities,
            onToggle: notifier.toggleTonality,
          ),
          const SizedBox(height: 8),
          _ChipSection(
            title: l10n.coldigomFilterRhythm,
            values: facets.options.rhythms,
            selected: selected.selectedRhythms,
            onToggle: notifier.toggleRhythm,
          ),
          const SizedBox(height: 8),
          _ChipSection(
            title: l10n.coldigomFilterCategory,
            values: facets.options.categories,
            selected: selected.selectedCategories,
            onToggle: notifier.toggleCategory,
          ),
          const SizedBox(height: 8),
          _IdNameChipSection(
            title: l10n.coldigomFilterTags,
            items: [
              for (final t in facets.options.tags) (id: t.id, name: t.name),
            ],
            selectedIds: selected.selectedTagIds,
            onToggle: notifier.toggleTag,
          ),
          const SizedBox(height: 8),
          _IdNameChipSection(
            title: l10n.coldigomFilterMaterials,
            items: [
              for (final m in facets.materialKinds) (id: m.id, name: m.name),
            ],
            selectedIds: selected.selectedMaterialKindIds,
            onToggle: notifier.toggleMaterialKind,
          ),
        ],
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<String> values;
  final Set<String> selected;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final value in values)
              FilterChip(
                label: Text(value),
                selected: selected.contains(value),
                showCheckmark: false,
                selectedColor: AppColors.gold.withValues(alpha: 0.3),
                backgroundColor: AppColors.card,
                side: BorderSide(
                  color: selected.contains(value)
                      ? AppColors.gold
                      : AppColors.title,
                  width: selected.contains(value) ? 2 : 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                onSelected: (_) => onToggle(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _IdNameChipSection extends StatelessWidget {
  const _IdNameChipSection({
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.onToggle,
  });

  final String title;
  final List<({String id, String name})> items;
  final Set<String> selectedIds;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final item in items)
              FilterChip(
                label: Text(item.name),
                selected: selectedIds.contains(item.id),
                showCheckmark: false,
                selectedColor: AppColors.gold.withValues(alpha: 0.3),
                backgroundColor: AppColors.card,
                side: BorderSide(
                  color: selectedIds.contains(item.id)
                      ? AppColors.gold
                      : AppColors.title,
                  width: selectedIds.contains(item.id) ? 2 : 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                onSelected: (_) => onToggle(item.id),
              ),
          ],
        ),
      ],
    );
  }
}
