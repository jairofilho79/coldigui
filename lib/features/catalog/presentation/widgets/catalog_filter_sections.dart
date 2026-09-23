import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filter_options_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef _ChipItem = ({String id, String name});

/// Secções de chips dos filtros do catálogo (tom, ritmo, categoria, tags,
/// tipo de material) — as mesmas na página inicial e na /biblioteca.
///
/// As opções vêm do índice local ([catalogFilterOptionsProvider]); a seleção
/// é [catalogFiltersProvider]. Secção sem opções não aparece. Um valor
/// selecionado que o catálogo não tem (pref ou link antigo, valor que sumiu
/// do coldigom) continua visível e marcado — senão o filtro ficaria ativo sem
/// chip para o desmarcar.
class CatalogFilterSections extends ConsumerWidget {
  const CatalogFilterSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final options = ref.watch(catalogFilterOptionsProvider);
    final selected = ref.watch(catalogFiltersProvider);
    final notifier = ref.read(catalogFiltersProvider.notifier);

    final sections = [
      _ChipSection(
        title: l10n.coldigomFilterTonality,
        items: _withSelected(_named(options.tonalities), selected.tonalities),
        selectedIds: selected.tonalities,
        onToggle: notifier.toggleTonality,
      ),
      _ChipSection(
        title: l10n.coldigomFilterRhythm,
        items: _withSelected(_named(options.rhythms), selected.rhythms),
        selectedIds: selected.rhythms,
        onToggle: notifier.toggleRhythm,
      ),
      _ChipSection(
        title: l10n.coldigomFilterCategory,
        items: _withSelected(_named(options.categories), selected.categories),
        selectedIds: selected.categories,
        onToggle: notifier.toggleCategory,
      ),
      _ChipSection(
        title: l10n.coldigomFilterTags,
        items: _withSelected(_named(options.tags), selected.tags),
        selectedIds: selected.tags,
        onToggle: notifier.toggleTag,
      ),
      _ChipSection(
        title: l10n.coldigomFilterMaterials,
        items: _withSelected([
          for (final kind in options.materialKinds)
            (id: kind.id, name: kind.name),
        ], selected.materialKindIds),
        selectedIds: selected.materialKindIds,
        onToggle: notifier.toggleMaterialKind,
      ),
    ].where((section) => section.items.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          sections[i],
        ],
      ],
    );
  }

  static List<_ChipItem> _named(List<String> values) => [
    for (final value in values) (id: value, name: value),
  ];

  static List<_ChipItem> _withSelected(
    List<_ChipItem> items,
    Set<String> selected,
  ) {
    final known = {for (final item in items) item.id};
    final missing = [
      for (final id in selected)
        if (!known.contains(id)) id,
    ]..sort();
    return [...items, for (final id in missing) (id: id, name: id)];
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.onToggle,
  });

  final String title;
  final List<_ChipItem> items;
  final Set<String> selectedIds;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
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
