import 'package:flutter/material.dart';

import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../core/utils/louvor_search_tokens.dart';
import '../../../../../core/utils/material_id_kind.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/domain/entities/material_kind_taxonomy.dart';
import '../../../../catalog/domain/utils/louvor_material_icons.dart';
import '../../../../catalog/domain/utils/material_kind_selection.dart';
import '../../../../catalog/presentation/widgets/material_kind_chips.dart';
import '../../../domain/entities/coldigom_download_target.dart';
import '../../providers/offline_coldigom_stats_provider.dart';
import 'coldigom_section.dart' show coldigomSizeLabel;

/// Rótulo traduzido do tipo de material para o card offline.
String offlineMaterialKindLabel(AppLocalizations l10n, MaterialKind kind) {
  return switch (kind) {
    MaterialKind.pdf => 'PDF',
    MaterialKind.chord => l10n.materialKindChordExtracted,
    MaterialKind.gesture => l10n.materialKindGestureExtracted,
    MaterialKind.audio => l10n.audioMaterialSection,
    MaterialKind.youtube => l10n.youtubeMaterialSection,
    MaterialKind.lyrics => l10n.lyricsTab,
    MaterialKind.unknown => '',
  };
}

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
  Map<MaterialKind, ColdigomTypeStats> get types;
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

  @override
  Map<MaterialKind, ColdigomTypeStats> get types => kind.effectiveTypes;
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

  @override
  Map<MaterialKind, ColdigomTypeStats> get types {
    final result = <MaterialKind, ColdigomTypeStats>{};
    final allStats = [
      ?parentStats,
      ...children,
    ];
    for (final s in allStats) {
      for (final entry in s.effectiveTypes.entries) {
        final existing = result[entry.key];
        if (existing == null) {
          result[entry.key] = entry.value;
        } else {
          result[entry.key] = ColdigomTypeStats(
            kind: entry.key,
            rawType: entry.value.rawType,
            total: existing.total + entry.value.total,
            downloaded: existing.downloaded + entry.value.downloaded,
            bytesKnown: existing.bytesKnown + entry.value.bytesKnown,
            bytesEstimated: existing.bytesEstimated + entry.value.bytesEstimated,
            pendingBytes: existing.pendingBytes + entry.value.pendingBytes,
          );
        }
      }
    }
    return result;
  }
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

/// Chip/card individual de tipo de material no `/offline` com dados de armazenamento
/// e divisão por material type.
class OfflineKindChip extends StatelessWidget {
  const OfflineKindChip({
    super.key,
    required this.kind,
    required this.l10n,
    required this.checked,
    required this.enabled,
    required this.onChanged,
    this.selection = const {},
    this.onToggleType,
    this.look = MaterialKindChipLook.normal,
    this.isHighlighted = false,
  });

  final ColdigomKindStats kind;
  final AppLocalizations l10n;
  final bool checked;
  final bool enabled;
  final VoidCallback onChanged;
  final Set<String> selection;
  final void Function(MaterialKind type)? onToggleType;
  final MaterialKindChipLook look;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final types = kind.effectiveTypes;
    final hasSelectedType = types.keys.any(
      (t) => isOfflineTypeSelected(
        kindId: kind.kindId,
        type: t,
        selection: selection,
      ),
    );
    final allSelected = types.isNotEmpty &&
        types.keys.every(
          (t) => isOfflineTypeSelected(
            kindId: kind.kindId,
            type: t,
            selection: selection,
          ),
        );

    final isSelected = checked || look == MaterialKindChipLook.selected || allSelected;
    final isPartial = !isSelected && hasSelectedType;
    final isIncluded = look == MaterialKindChipLook.included;
    final isFullyDownloaded = kind.total > 0 && kind.downloaded == kind.total;
    final isPartiallyDownloaded =
        kind.downloaded > 0 && kind.downloaded < kind.total;

    final sizeStr = coldigomSizeLabel(
      kind.bytesTotal,
      estimated: kind.hasEstimate,
    );

    final borderColor = isHighlighted
        ? AppColors.gold
        : (isSelected
            ? AppColors.gold
            : (isPartial || isIncluded
                ? AppColors.gold
                : AppColors.title.withValues(alpha: 0.22)));
    final borderWidth =
        isHighlighted ? 2.2 : (isSelected ? 2.0 : (isPartial ? 1.5 : 1.0));
    final borderSide = BorderSide(color: borderColor, width: borderWidth);

    final cardShape = isIncluded
        ? DashedRoundedRectangleBorder(
            side: borderSide,
            borderRadius: BorderRadius.circular(12),
          )
        : RoundedRectangleBorder(
            side: borderSide,
            borderRadius: BorderRadius.circular(12),
          );

    final backgroundColor = isSelected
        ? AppColors.gold.withValues(alpha: 0.16)
        : (isPartial || isIncluded
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.card);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 260,
        maxWidth: 360,
        minHeight: 140,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.55),
                    blurRadius: 10,
                    spreadRadius: 1.5,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: backgroundColor,
          shape: cardShape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onChanged : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: isSelected ? true : (isPartial ? null : false),
                        tristate: true,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        activeColor: AppColors.gold,
                        checkColor: AppColors.title,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: BorderSide(
                          color: (isSelected || isPartial)
                              ? AppColors.gold
                              : AppColors.title.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        onChanged: enabled ? (_) => onChanged() : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        kind.kindName,
                        style: AppTypography.body.copyWith(
                          fontSize: 13.5,
                          fontWeight: (isSelected || isPartial)
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: AppColors.title,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFullyDownloaded) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: AppColors.gold,
                      ),
                    ],
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30, top: 3, bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 13.5,
                        color: AppColors.title.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPartiallyDownloaded
                            ? '${kind.downloaded}/${kind.total} arq.'
                            : '${kind.total} arq.',
                        style: AppTypography.label.copyWith(
                          fontSize: 11,
                          color: AppColors.title.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.storage_outlined,
                        size: 13.5,
                        color: AppColors.title.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sizeStr,
                        style: AppTypography.label.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.title.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPartiallyDownloaded) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 30, top: 2, bottom: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        minHeight: 2.5,
                        value: kind.downloaded / kind.total,
                        backgroundColor: AppColors.title.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.gold,
                        ),
                      ),
                    ),
                  ),
                ],
                if (types.isNotEmpty) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(
                          height: 12,
                          thickness: 0.8,
                          color: AppColors.title.withValues(alpha: 0.12),
                        ),
                        for (final entry in types.entries)
                          _MaterialTypeRow(
                            kindId: kind.kindId,
                            matKind: entry.key,
                            typeStats: entry.value,
                            l10n: l10n,
                            enabled: enabled,
                            selected: isOfflineTypeSelected(
                              kindId: kind.kindId,
                              type: entry.key,
                              selection: selection,
                            ),
                            onToggle: onToggleType != null
                                ? () => onToggleType!(entry.key)
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}

/// Linha de divisão por tipo de material com ícone, contagem e tamanho.
class _MaterialTypeRow extends StatelessWidget {
  const _MaterialTypeRow({
    required this.kindId,
    required this.matKind,
    required this.typeStats,
    required this.l10n,
    required this.enabled,
    required this.selected,
    required this.onToggle,
  });

  final String kindId;
  final MaterialKind matKind;
  final ColdigomTypeStats typeStats;
  final AppLocalizations l10n;
  final bool enabled;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final typeSizeStr = coldigomSizeLabel(
      typeStats.bytesTotal,
      estimated: typeStats.hasEstimate,
    );

    return InkWell(
      onTap: enabled && onToggle != null ? onToggle : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: selected,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.gold,
                checkColor: AppColors.title,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
                side: BorderSide(
                  color: selected
                      ? AppColors.gold
                      : AppColors.title.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                onChanged: enabled && onToggle != null ? (_) => onToggle!() : null,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LouvorMaterialIcons.forKind(matKind),
              size: 15,
              color: AppColors.title.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                offlineMaterialKindLabel(l10n, matKind),
                style: AppTypography.label.copyWith(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.title,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.folder_outlined,
              size: 12,
              color: AppColors.title.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 3),
            Text(
              '${typeStats.total}',
              style: AppTypography.label.copyWith(
                fontSize: 10.5,
                color: AppColors.title.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.storage_outlined,
              size: 12,
              color: AppColors.title.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 3),
            Text(
              typeSizeStr,
              style: AppTypography.label.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.title.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip de família de tipos no `/offline`: corpo marca/desmarca o conjunto;
/// seta recolhe ou expande as variantes com hierarquia visual clara e fundo zebrado.
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
    required this.l10n,
    this.selection = const {},
    this.onToggleType,
    this.isHighlighted = false,
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
  final AppLocalizations l10n;
  final Set<String> selection;
  final void Function(MaterialKind type)? onToggleType;
  final bool isHighlighted;

  Widget _buildFamilyCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSelected = state == MaterialKindFamilyState.selected;
    final isPartial = state == MaterialKindFamilyState.refined;
    final isFullyDownloaded = unit.total > 0 && unit.downloaded == unit.total;
    final isPartiallyDownloaded =
        unit.downloaded > 0 && unit.downloaded < unit.total;

    final sizeStr = coldigomSizeLabel(
      unit.bytesTotal,
      estimated: unit.hasEstimate,
    );

    final borderColor = isHighlighted
        ? AppColors.gold
        : ((isSelected || isPartial)
            ? AppColors.gold
            : AppColors.title.withValues(alpha: 0.22));
    final borderWidth =
        isHighlighted ? 2.2 : (isSelected ? 2.0 : (isPartial ? 1.5 : 1.0));
    final borderSide = BorderSide(color: borderColor, width: borderWidth);

    final cardShape = isPartial
        ? DashedRoundedRectangleBorder(
            side: borderSide,
            borderRadius: BorderRadius.circular(12),
          )
        : RoundedRectangleBorder(
            side: borderSide,
            borderRadius: BorderRadius.circular(12),
          );

    final backgroundColor = isSelected
        ? AppColors.gold.withValues(alpha: 0.16)
        : (isPartial
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.card);

    final types = unit.types;

    return Material(
      color: backgroundColor,
      shape: cardShape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onToggle : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    selected: isSelected,
                    label: bodyLabel,
                    value: isPartial ? refinedValue : null,
                    onTap: enabled ? onToggle : null,
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: isSelected ? true : (isPartial ? null : false),
                        tristate: true,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        activeColor: AppColors.gold,
                        checkColor: AppColors.title,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: BorderSide(
                          color: (isSelected || isPartial)
                              ? AppColors.gold
                              : AppColors.title.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        onChanged: enabled ? (_) => onToggle() : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            unit.name,
                            style: AppTypography.body.copyWith(
                              fontSize: 13.5,
                              fontWeight: (isSelected || isPartial)
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.title,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.title.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.offlineKindVariantsCount(unit.children.length),
                            style: AppTypography.label.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.title.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        if (isFullyDownloaded) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: AppColors.gold,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: expandTooltip,
                    expanded: expanded,
                    onTap: enabled ? onExpand : null,
                    excludeSemantics: true,
                    child: Tooltip(
                      message: expandTooltip,
                      child: InkWell(
                        onTap: enabled ? onExpand : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                            color: AppColors.title,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 3, bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 13.5,
                      color: AppColors.title.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPartiallyDownloaded
                          ? '${unit.downloaded}/${unit.total} arq.'
                          : '${unit.total} arq.',
                      style: AppTypography.label.copyWith(
                        fontSize: 11,
                        color: AppColors.title.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.storage_outlined,
                      size: 13.5,
                      color: AppColors.title.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sizeStr,
                      style: AppTypography.label.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.title.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPartiallyDownloaded) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 30, top: 2, bottom: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      minHeight: 2.5,
                      value: unit.downloaded / unit.total,
                      backgroundColor: AppColors.title.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.gold,
                      ),
                    ),
                  ),
                ),
              ],
              if (types.isNotEmpty) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(
                        height: 12,
                        thickness: 0.8,
                        color: AppColors.title.withValues(alpha: 0.12),
                      ),
                      for (final entry in types.entries)
                        _MaterialTypeRow(
                          kindId: unit.headId,
                          matKind: entry.key,
                          typeStats: entry.value,
                          l10n: l10n,
                          enabled: enabled,
                          selected: isOfflineTypeSelected(
                            kindId: unit.headId,
                            type: entry.key,
                            selection: selection,
                          ),
                          onToggle: onToggleType != null
                              ? () => onToggleType!(entry.key)
                              : null,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 260,
        maxWidth: 360,
        minHeight: 140,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.55),
                    blurRadius: 10,
                    spreadRadius: 1.5,
                  ),
                ]
              : null,
        ),
        child: _buildFamilyCard(context),
      ),
    );
  }
}

/// Contêiner com fundo zebrado e hierarquia visual conectando o pai e as variantes.
class OfflineKindFamilyGroup extends StatelessWidget {
  const OfflineKindFamilyGroup({
    super.key,
    required this.unit,
    required this.familyChip,
    required this.children,
  });

  final OfflineKindFamilyUnit unit;
  final Widget familyChip;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: familyChip,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 10, bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: 18,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.offlineKindVariantsTitle(unit.name, unit.children.length),
                  style: AppTypography.label.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppColors.title.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 14),
            padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              spacing: 8,
              runSpacing: 8,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
