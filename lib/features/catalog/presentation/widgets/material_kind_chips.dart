import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../domain/utils/material_kind_selection.dart';

const _pill = BorderRadius.all(Radius.circular(24));

/// Borda arredondada tracejada: família refinada e filho «incluído» (spec
/// filtro-materiais §5.2). `copyWith` preserva o tracejado — o `FilterChip`
/// aplica o `side` por ele.
class DashedRoundedRectangleBorder extends RoundedRectangleBorder {
  const DashedRoundedRectangleBorder({super.side, super.borderRadius});

  static const double _dash = 5;
  static const double _gap = 3;

  @override
  DashedRoundedRectangleBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) => DashedRoundedRectangleBorder(
    side: side ?? this.side,
    borderRadius: borderRadius ?? this.borderRadius,
  );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    final rrect = borderRadius
        .resolve(textDirection)
        .toRRect(rect)
        .deflate(side.width / 2);
    final path = Path()..addRRect(rrect);
    final paint = side.toPaint();
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }
}

enum MaterialKindChipLook { normal, selected, included }

/// Chip de um kind — o `FilterChip` de sempre da seção, mais o visual
/// «incluído» (filho de uma família marcada inteira).
class MaterialKindChip extends StatelessWidget {
  const MaterialKindChip({
    super.key,
    required this.label,
    required this.look,
    required this.onPressed,
  });

  final String label;
  final MaterialKindChipLook look;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final selected = look == MaterialKindChipLook.selected;
    final included = look == MaterialKindChipLook.included;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.gold.withValues(alpha: 0.3),
      backgroundColor: included
          ? AppColors.gold.withValues(alpha: 0.12)
          : AppColors.card,
      side: BorderSide(
        color: look == MaterialKindChipLook.normal
            ? AppColors.title
            : AppColors.gold,
        width: selected ? 2 : 1.5,
      ),
      shape: included
          ? const DashedRoundedRectangleBorder(borderRadius: _pill)
          : const RoundedRectangleBorder(borderRadius: _pill),
      onSelected: (_) => onPressed(),
    );
  }
}

/// Família recolhida: o corpo (nome do pai + nº de variantes) marca o pai;
/// a seta abre as variantes (spec filtro-materiais §5.2).
class MaterialKindFamilyChip extends StatelessWidget {
  const MaterialKindFamilyChip({
    super.key,
    required this.label,
    required this.count,
    required this.state,
    required this.expanded,
    required this.onToggle,
    required this.onExpand,
    required this.expandTooltip,
  });

  final String label;
  final int count;
  final MaterialKindFamilyState state;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onExpand;
  final String expandTooltip;

  @override
  Widget build(BuildContext context) {
    final none = state == MaterialKindFamilyState.none;
    final side = BorderSide(
      color: none ? AppColors.title : AppColors.gold,
      width: none ? 1.5 : 2,
    );
    final labelStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: AppColors.title);
    return Material(
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
              button: true,
              selected: state == MaterialKindFamilyState.selected,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: labelStyle),
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: AppColors.title.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: labelStyle?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
            Tooltip(
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
          ],
        ),
      ),
    );
  }
}

/// Chip de Tipo (PDF, Cifra…): mais baixo e mais quadrado que o de kind;
/// marcado, fica preenchido de vinho (spec filtro-materiais §5.1).
class MaterialTypeChip extends StatelessWidget {
  const MaterialTypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.card : AppColors.title;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
      labelStyle: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: AppColors.title,
      backgroundColor: Colors.transparent,
      side: BorderSide(color: AppColors.title.withValues(alpha: 0.7)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      onSelected: (_) => onPressed(),
    );
  }
}
