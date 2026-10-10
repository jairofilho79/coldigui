import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/domain/utils/catalog_tag_hierarchy.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filter_options_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'material_kind_filter_section.dart';

typedef _ChipItem = ({String id, String name});

/// Secções de chips dos filtros do catálogo (tom, ritmo, tags) — as
/// mesmas na página inicial e na /biblioteca. O tipo de material tem seção
/// própria, [MaterialKindFilterSection], com classes e famílias.
///
/// As opções vêm do índice local ([catalogFilterOptionsProvider]); a seleção
/// é [catalogFiltersProvider]. Secção sem opções não aparece. Um valor
/// selecionado que o catálogo não tem (pref ou link antigo, valor que sumiu
/// do coldigom) continua visível e marcado — senão o filtro ficaria ativo sem
/// chip para o desmarcar.
///
/// Tags sob demanda: «Tags» só tem as raízes; as filhas de cada tag marcada
/// aparecem em «Subtags» (recursivo — subtag marcada abre as filhas dela),
/// rotuladas só pelo último nível (`PES · 9.2026` → `9.2026`).
class CatalogFilterSections extends ConsumerWidget {
  const CatalogFilterSections({
    super.key,
    this.scope = CatalogFilterScope.home,
  });

  /// Escopo de filtros associado à tela (página inicial ou biblioteca).
  final CatalogFilterScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final options = ref.watch(catalogFilterOptionsProvider);
    final selected = ref.watch(catalogFiltersProviderFor(scope));
    final notifier = ref.read(catalogFiltersProviderFor(scope).notifier);

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
        title: l10n.coldigomFilterTags,
        items: _withSelected(
          _named([
            for (final tag in options.tags)
              if (catalogTagParent(tag) == null) tag,
          ]),
          {
            for (final tag in selected.tags)
              if (catalogTagParent(tag) == null) tag,
          },
        ),
        selectedIds: selected.tags,
        onToggle: notifier.toggleTag,
      ),
      _ChipSection(
        title: l10n.coldigomFilterSubtags,
        items: [
          for (final item in _withSelected(
            _named([
              for (final tag in options.tags)
                if (selected.tags.contains(catalogTagParent(tag))) tag,
            ]),
            {
              for (final tag in selected.tags)
                if (catalogTagParent(tag) != null) tag,
            },
          ))
            (id: item.id, name: catalogTagLeaf(item.id)),
        ],
        selectedIds: selected.tags,
        onToggle: notifier.toggleTag,
      ),
    ].where((section) => section.items.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          sections[i],
        ],
        if (options.materialKinds.isNotEmpty ||
            selected.materialKindIds.isNotEmpty) ...[
          if (sections.isNotEmpty) const SizedBox(height: 8),
          MaterialKindFilterSection(scope: scope),
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
