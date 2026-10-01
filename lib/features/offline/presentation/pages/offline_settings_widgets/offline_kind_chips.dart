import 'package:flutter/material.dart';

import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../core/utils/louvor_search_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/domain/entities/material_kind_taxonomy.dart';
import '../../../../catalog/domain/utils/material_kind_selection.dart';
import '../../../../catalog/presentation/widgets/material_kind_chips.dart';
import '../../providers/offline_coldigom_stats_provider.dart';
import 'coldigom_section.dart' show coldigomSizeLabel;

const _pill = BorderRadius.all(Radius.circular(24));

/// Um elemento da lista de download: kind individual ou família recolhida.
sealed class OfflineKindUnit {
  const OfflineKindUnit();

  String get headId;
  String get name;
  int get total;
  int get downloaded;
  int get bytesTotal;
  int get pendingBytes;
  bool get hasEstimate;
}

final class OfflineKindSingleUnit extends OfflineKindUnit {
  const OfflineKindSingleUnit(this.kind);

  final ColdigomKindStats kind;

  @override
  String get headId => kind.kindId;

  @override
  String get name => kind.kindName;

  @override
  int get total => kind.total;

  @override
  int get downloaded => kind.downloaded;

  @override
  int get bytesTotal => kind.bytesTotal;

  @override
  int get pendingBytes => kind.pendingBytes;

  @override
  bool get hasEstimate => kind.hasEstimate;
}

final class OfflineKindFamilyUnit extends OfflineKindUnit {
  const OfflineKindFamilyUnit({
    required this.parentId,
    required this.parentName,
    required this.parentStats,
    required this.children,
  });

  final String parentId;
  final String parentName;
  final ColdigomKindStats? parentStats;
  final List<ColdigomKindStats> children;

  @override
  String get headId => parentId;

  @override
  String get name => parentName;

  @override
  int get total =>
      (parentStats?.total ?? 0) +
      children.fold(0, (sum, c) => sum + c.total);

  @override
  int get downloaded =>
      (parentStats?.downloaded ?? 0) +
      children.fold(0, (sum, c) => sum + c.downloaded);

  @override
  int get bytesTotal =>
      (parentStats?.bytesTotal ?? 0) +
      children.fold(0, (sum, c) => sum + c.bytesTotal);

  @override
  int get pendingBytes =>
      (parentStats?.pendingBytes ?? 0) +
      children.fold(0, (sum, c) => sum + c.pendingBytes);

  @override
  bool get hasEstimate =>
      (parentStats?.hasEstimate ?? false) ||
      children.any((c) => c.hasEstimate);
}

/// Seção de kinds no `/offline` (agrupada por classe da taxonomia).
class OfflineKindSection {
  const OfflineKindSection({
    required this.classId,
    required this.label,
    required this.units,
  });

  final String? classId;
  final String? label;
  final List<OfflineKindUnit> units;

  int get count => units.fold(
    0,
    (sum, u) => switch (u) {
      OfflineKindSingleUnit() => sum + 1,
      OfflineKindFamilyUnit(:final children, :final parentStats) =>
        sum + children.length + (parentStats != null ? 1 : 0),
    },
  );
}

/// Agrupa [kinds] em seções por classe taxonômica e famílias recolhidas.
List<OfflineKindSection> buildOfflineKindSections({
  required List<ColdigomKindStats> kinds,
  required MaterialKindTaxonomy taxonomy,
}) {
  if (kinds.isEmpty) return const [];

  if (taxonomy.classes.isEmpty) {
    final sorted = [...kinds]
      ..sort((a, b) => _compareLabels(a.kindName, b.kindName));
    return [
      OfflineKindSection(
        classId: null,
        label: null,
        units: [for (final k in sorted) OfflineKindSingleUnit(k)],
      ),
    ];
  }

  final childrenByParent = <String, List<ColdigomKindStats>>{};
  final roots = <ColdigomKindStats>[];
  for (final k in kinds) {
    final parentId = taxonomy.parentOf(k.kindId);
    if (parentId == null) {
      roots.add(k);
    } else {
      childrenByParent.putIfAbsent(parentId, () => []).add(k);
    }
  }

  int compareStats(ColdigomKindStats a, ColdigomKindStats b) {
    final orderA = taxonomy.kinds[a.kindId]?.order ?? 1 << 30;
    final orderB = taxonomy.kinds[b.kindId]?.order ?? 1 << 30;
    final byOrder = orderA.compareTo(orderB);
    if (byOrder != 0) return byOrder;
    return _compareLabels(a.kindName, b.kindName);
  }

  int compareUnits(OfflineKindUnit a, OfflineKindUnit b) {
    final orderA = taxonomy.kinds[a.headId]?.order ?? 1 << 30;
    final orderB = taxonomy.kinds[b.headId]?.order ?? 1 << 30;
    final byOrder = orderA.compareTo(orderB);
    if (byOrder != 0) return byOrder;
    return _compareLabels(a.name, b.name);
  }

  final placed = <OfflineKindUnit>[];
  for (final root in roots) {
    final kids = childrenByParent.remove(root.kindId);
    if (kids == null || kids.isEmpty) {
      placed.add(OfflineKindSingleUnit(root));
    } else {
      placed.add(
        OfflineKindFamilyUnit(
          parentId: root.kindId,
          parentName: root.kindName,
          parentStats: root,
          children: kids..sort(compareStats),
        ),
      );
    }
  }

  // Filhos cujo pai não tem material direto no catálogo
  for (final entry in childrenByParent.entries) {
    final parentId = entry.key;
    final kids = entry.value..sort(compareStats);
    if (kids.length == 1) {
      placed.add(OfflineKindSingleUnit(kids.single));
    } else {
      final parentName = taxonomy.kinds[parentId]?.name ?? parentId;
      placed.add(
        OfflineKindFamilyUnit(
          parentId: parentId,
          parentName: parentName,
          parentStats: null,
          children: kids,
        ),
      );
    }
  }

  final knownClasses = {for (final c in taxonomy.classes) c.id};
  final byClass = <String?, List<OfflineKindUnit>>{};
  for (final u in placed) {
    final classId = taxonomy.kinds[u.headId]?.classId;
    byClass
        .putIfAbsent(knownClasses.contains(classId) ? classId : null, () => [])
        .add(u);
  }

  final sections = <OfflineKindSection>[];
  for (final c in taxonomy.classes) {
    final units = byClass[c.id];
    if (units != null && units.isNotEmpty) {
      units.sort(compareUnits);
      sections.add(
        OfflineKindSection(
          classId: c.id,
          label: c.label,
          units: units,
        ),
      );
    }
  }

  final otherUnits = byClass[null];
  if (otherUnits != null && otherUnits.isNotEmpty) {
    otherUnits.sort(compareUnits);
    sections.add(
      OfflineKindSection(
        classId: null,
        label: null,
        units: otherUnits,
      ),
    );
  }

  return sections;
}

int _compareLabels(String a, String b) {
  final byNormalized = LouvorSearchTokens.normalize(a)
      .compareTo(LouvorSearchTokens.normalize(b));
  return byNormalized != 0 ? byNormalized : a.compareTo(b);
}

/// Cabeçalho da classe/seção: nome em caixa-alta, contagem e linha divisora.
class OfflineClassHeader extends StatelessWidget {
  const OfflineClassHeader({
    super.key,
    required this.label,
    required this.count,
  });

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
      padding: const EdgeInsets.only(top: 8, bottom: 6),
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

/// Chip individual de tipo de material no `/offline` com dados de armazenamento.
class OfflineKindChip extends StatelessWidget {
  const OfflineKindChip({
    super.key,
    required this.kind,
    required this.l10n,
    required this.checked,
    required this.enabled,
    required this.onChanged,
    this.look = MaterialKindChipLook.normal,
  });

  final ColdigomKindStats kind;
  final AppLocalizations l10n;
  final bool checked;
  final bool enabled;
  final VoidCallback onChanged;
  final MaterialKindChipLook look;

  @override
  Widget build(BuildContext context) {
    final isSelected = checked || look == MaterialKindChipLook.selected;
    final isIncluded = look == MaterialKindChipLook.included;
    final isFullyDownloaded = kind.total > 0 && kind.downloaded == kind.total;
    final isPartiallyDownloaded =
        kind.downloaded > 0 && kind.downloaded < kind.total;

    final sizeStr = coldigomSizeLabel(
      kind.bytesTotal,
      estimated: kind.hasEstimate,
    );
    final badgeStr = isPartiallyDownloaded
        ? '${kind.downloaded}/${kind.total} · $sizeStr'
        : '${kind.total} · $sizeStr';

    final tooltip = l10n.offlineColdigomKindSummary(kind.total, sizeStr);

    return Tooltip(
      message: tooltip,
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        selectedColor: AppColors.gold.withValues(alpha: 0.3),
        backgroundColor: isIncluded
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.card,
        side: BorderSide(
          color: !isSelected && look == MaterialKindChipLook.normal
              ? AppColors.title
              : AppColors.gold,
          width: isSelected ? 2 : 1.5,
        ),
        shape: isIncluded
            ? const DashedRoundedRectangleBorder(borderRadius: _pill)
            : const RoundedRectangleBorder(borderRadius: _pill),
        onSelected: enabled ? (_) => onChanged() : null,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        label: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFullyDownloaded) ...[
                    Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: isSelected
                          ? AppColors.title
                          : AppColors.gold,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    kind.kindName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.title,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.gold.withValues(alpha: 0.25)
                          : AppColors.title.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      badgeStr,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.title.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
              if (isPartiallyDownloaded) ...[
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      value: kind.downloaded / kind.total,
                      backgroundColor: AppColors.title.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.gold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de família de tipos no `/offline`: corpo marca/desmarca o conjunto;
/// seta recolhe ou expande as variantes.
class OfflineKindFamilyChip extends StatelessWidget {
  const OfflineKindFamilyChip({
    super.key,
    required this.unit,
    required this.state,
    required this.expanded,
    required this.enabled,
    required this.onToggle,
    required this.onExpand,
    required this.expandTooltip,
    required this.bodyLabel,
    required this.refinedValue,
  });

  final OfflineKindFamilyUnit unit;
  final MaterialKindFamilyState state;
  final bool expanded;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onExpand;
  final String expandTooltip;
  final String bodyLabel;
  final String refinedValue;

  @override
  Widget build(BuildContext context) {
    final none = state == MaterialKindFamilyState.none;
    final side = BorderSide(
      color: none ? AppColors.title : AppColors.gold,
      width: none ? 1.5 : 2,
    );
    final labelStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: AppColors.title);

    final isFullyDownloaded =
        unit.total > 0 && unit.downloaded == unit.total;
    final isPartiallyDownloaded =
        unit.downloaded > 0 && unit.downloaded < unit.total;
    final sizeStr = coldigomSizeLabel(
      unit.bytesTotal,
      estimated: unit.hasEstimate,
    );
    final badgeStr = isPartiallyDownloaded
        ? '${unit.downloaded}/${unit.total} · $sizeStr'
        : '${unit.children.length} var. · $sizeStr';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: Center(
        widthFactor: 1,
        child: Material(
          color: state == MaterialKindFamilyState.selected
              ? AppColors.gold.withValues(alpha: 0.3)
              : AppColors.card,
          shape: state == MaterialKindFamilyState.refined
              ? DashedRoundedRectangleBorder(side: side, borderRadius: _pill)
              : RoundedRectangleBorder(side: side, borderRadius: _pill),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  container: true,
                  button: true,
                  selected: state == MaterialKindFamilyState.selected,
                  label: bodyLabel,
                  value: state == MaterialKindFamilyState.refined
                      ? refinedValue
                      : null,
                  onTap: enabled ? onToggle : null,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: enabled ? onToggle : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFullyDownloaded) ...[
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 13,
                                  color: state == MaterialKindFamilyState.selected
                                      ? AppColors.title
                                      : AppColors.gold,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(unit.name, style: labelStyle),
                              const SizedBox(width: 6),
                              Container(
                                constraints:
                                    const BoxConstraints(minWidth: 18),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: state == MaterialKindFamilyState.selected
                                      ? AppColors.gold.withValues(alpha: 0.25)
                                      : AppColors.title.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  badgeStr,
                                  textAlign: TextAlign.center,
                                  style: labelStyle?.copyWith(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isPartiallyDownloaded) ...[
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SizedBox(
                                width: 80,
                                height: 2,
                                child: LinearProgressIndicator(
                                  minHeight: 2,
                                  value: unit.downloaded / unit.total,
                                  backgroundColor: AppColors.title
                                      .withValues(alpha: 0.12),
                                  valueColor: const AlwaysStoppedAnimation(
                                    AppColors.gold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.title.withValues(alpha: 0.16),
                ),
                Semantics(
                  button: true,
                  label: expandTooltip,
                  expanded: expanded,
                  onTap: onExpand,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: expandTooltip,
                    child: InkWell(
                      onTap: onExpand,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: AppColors.title,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
