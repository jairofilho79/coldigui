import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/louvor_group.dart';
import '../../domain/usecases/cluster_member_label.dart';

/// Barra com tags das versões/praises relacionados (mesmo `group_id`).
class RelatedPraisesBar extends StatefulWidget {
  const RelatedPraisesBar({
    required this.praises,
    required this.selectedPraise,
    required this.l10n,
    required this.onSelected,
    super.key,
  });

  final List<LouvorGroup> praises;
  final LouvorGroup selectedPraise;
  final AppLocalizations l10n;
  final ValueChanged<LouvorGroup> onSelected;

  @override
  State<RelatedPraisesBar> createState() => _RelatedPraisesBarState();
}

class _RelatedPraisesBarState extends State<RelatedPraisesBar> {
  double _dragDelta = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.swap_horiz,
              size: 14,
              color: AppColors.title.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              widget.l10n.relatedPraisesTitle.toUpperCase(),
              style: AppTypography.tagLabel.copyWith(
                color: AppColors.title.withValues(alpha: 0.7),
                letterSpacing: 1.1,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _dragDelta = 0,
          onHorizontalDragUpdate: (details) =>
              _dragDelta += details.primaryDelta ?? 0,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            final delta = _dragDelta;
            _dragDelta = 0;
            if (delta.abs() < 20 && velocity.abs() < 50) return;
            final currentIndex = widget.praises.indexWhere(
              (p) => p.groupId == widget.selectedPraise.groupId,
            );
            final isNext = delta != 0 ? delta < 0 : velocity < 0;
            final targetIndex =
                (currentIndex + (isNext ? 1 : -1) + widget.praises.length) %
                    widget.praises.length;
            widget.onSelected(widget.praises[targetIndex]);
          },
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final praise in widget.praises)
                _RelatedPraiseChip(
                  praise: praise,
                  allPraises: widget.praises,
                  isSelected: praise.groupId == widget.selectedPraise.groupId,
                  onTap: () => widget.onSelected(praise),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RelatedPraiseChip extends StatelessWidget {
  const _RelatedPraiseChip({
    required this.praise,
    required this.allPraises,
    required this.isSelected,
    required this.onTap,
  });

  final LouvorGroup praise;
  final List<LouvorGroup> allPraises;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = clusterMemberLabel(praise, allPraises) ??
        praise.coldigomMeta?.tagNames.firstOrNull ??
        (praise.numero.isNotEmpty ? '#${praise.numero}' : praise.nome);

    return Material(
      color: isSelected
          ? AppColors.gold.withValues(alpha: 0.28)
          : AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.gold
                  : AppColors.gold.withValues(alpha: 0.35),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: AppColors.title,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
