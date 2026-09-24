import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../domain/usecases/build_material_kind_sections.dart';
import '../../domain/utils/material_kind_selection.dart';
import '../providers/catalog_filter_options_provider.dart';
import '../providers/catalog_filters_provider.dart';
import 'material_kind_chips.dart';

/// Seção «Materiais» dos filtros (spec filtro-materiais §5): chips de Tipo,
/// uma seção por classe e as famílias recolhidas.
///
/// Os tipos marcados e as famílias abertas ficam só aqui — não vão para a
/// URL nem para as prefs, e voltam ao padrão quando o painel reabre.
class MaterialKindFilterSection extends ConsumerStatefulWidget {
  const MaterialKindFilterSection({super.key});

  @override
  ConsumerState<MaterialKindFilterSection> createState() =>
      _MaterialKindFilterSectionState();
}

class _MaterialKindFilterSectionState
    extends ConsumerState<MaterialKindFilterSection> {
  final Set<MaterialKind> _types = {};

  /// Abertura escolhida à mão; sem entrada, a família abre sozinha quando
  /// tem um filho marcado.
  final Map<String, bool> _open = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = ref.watch(
      catalogFilterOptionsProvider.select((o) => o.materialKinds),
    );
    final taxonomy = ref.watch(coldigomKindTaxonomyProvider);
    final selected = ref.watch(
      catalogFiltersProvider.select((s) => s.materialKindIds),
    );
    final notifier = ref.read(catalogFiltersProvider.notifier);
    final view = buildMaterialKindSections(
      options: options,
      taxonomy: taxonomy,
      types: _types,
      selected: selected,
    );
    // Sem classes na taxonomia (coldigom antigo, ou vazia): lista plana, sem
    // o rótulo «Outros» — não depende de quais seções estão visíveis agora,
    // senão um filtro de Tipo que esconde tudo que é classificado faria o
    // rótulo sumir mesmo com taxonomia ativa.
    final flat = taxonomy.classes.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.coldigomFilterMaterials, style: AppTypography.label),
        const SizedBox(height: 8),
        if (view.typeCounts.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.materialTypeFilterLabel.toUpperCase(),
                style: AppTypography.label.copyWith(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: AppColors.title.withValues(alpha: 0.7),
                ),
              ),
              MaterialTypeChip(
                label: l10n.materialTypeAll,
                selected: _types.isEmpty,
                onPressed: () => setState(_types.clear),
              ),
              for (final entry in view.typeCounts.entries)
                MaterialTypeChip(
                  label: _typeLabel(l10n, entry.key),
                  count: entry.value,
                  selected: _types.contains(entry.key),
                  onPressed: () => setState(() {
                    if (!_types.remove(entry.key)) _types.add(entry.key);
                  }),
                ),
            ],
          ),
        if (view.hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.materialKindHiddenByType(view.hiddenCount),
              style: AppTypography.hint(),
            ),
          ),
        for (final section in view.sections) ...[
          const SizedBox(height: 10),
          if (!flat)
            _ClassHeader(
              label: section.label ?? l10n.materialKindOtherClass,
              count: section.count,
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final unit in section.units)
                ..._unit(l10n, unit, selected, notifier.toggleMaterialKind),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _unit(
    AppLocalizations l10n,
    MaterialKindUnit unit,
    Set<String> selected,
    void Function(String) toggle,
  ) {
    switch (unit) {
      case MaterialKindSingleUnit(:final option):
        return [_kindChip(option, selected, toggle)];
      case MaterialKindFamilyUnit(:final parent, :final children):
        final childIds = [for (final c in children) c.id];
        final state = materialKindFamilyState(parent.id, childIds, selected);
        final open =
            _open[parent.id] ?? state == MaterialKindFamilyState.refined;
        return [
          MaterialKindFamilyChip(
            label: parent.name,
            count: children.length,
            state: state,
            expanded: open,
            onToggle: () => toggle(parent.id),
            onExpand: () => setState(() {
              _open[parent.id] = !open;
            }),
            expandTooltip: l10n.materialKindShowVariants(parent.name),
          ),
          if (open)
            SizedBox(
              width: double.infinity,
              child: Container(
                margin: const EdgeInsets.only(left: 14, top: 2, bottom: 4),
                padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.gold, width: 2),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final child in children)
                      state == MaterialKindFamilyState.selected
                          ? MaterialKindChip(
                              label: child.name,
                              look: MaterialKindChipLook.included,
                              onPressed: () => toggle(child.id),
                            )
                          : _kindChip(child, selected, toggle),
                  ],
                ),
              ),
            ),
        ];
    }
  }

  Widget _kindChip(
    CatalogKindOption option,
    Set<String> selected,
    void Function(String) toggle,
  ) => MaterialKindChip(
    label: option.name,
    look: selected.contains(option.id)
        ? MaterialKindChipLook.selected
        : MaterialKindChipLook.normal,
    onPressed: () => toggle(option.id),
  );

  static String _typeLabel(AppLocalizations l10n, MaterialKind type) =>
      switch (type) {
        MaterialKind.pdf => l10n.materialTypePdf,
        MaterialKind.chord => l10n.materialTypeChord,
        MaterialKind.audio => l10n.materialTypeAudio,
        MaterialKind.youtube => l10n.materialTypeYoutube,
        MaterialKind.gesture => l10n.materialTypeGesture,
        MaterialKind.lyrics || MaterialKind.unknown => type.name,
      };
}

/// Rótulo da classe: caixa-alta pequena, contagem e um fio até a borda.
class _ClassHeader extends StatelessWidget {
  const _ClassHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.label.copyWith(
      fontSize: 11.5,
      letterSpacing: 1,
      color: AppColors.title.withValues(alpha: 0.7),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: style),
          const SizedBox(width: 6),
          Text('$count', style: style.copyWith(fontWeight: FontWeight.w400)),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.title.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}
