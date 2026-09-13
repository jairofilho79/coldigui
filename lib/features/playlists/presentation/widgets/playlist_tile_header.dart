import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/playlist_tab.dart';

/// Cabeçalho de [PlaylistListTile] — nome, hora, contagem, badges de
/// publicação, botão primário (salvar/favoritar) e menu de ações.
///
/// Extraído de `playlist_list_tile.dart` (E4) — sem mudança de comportamento.
class PlaylistTileHeader extends StatelessWidget {
  const PlaylistTileHeader({
    required this.nome,
    required this.hora,
    required this.countLabel,
    required this.isPublished,
    required this.publicBadgeLabel,
    required this.categoryLabel,
    required this.reachLabel,
    required this.tab,
    required this.saveTooltip,
    required this.favoriteOffTooltip,
    required this.favoriteOnTooltip,
    required this.expanded,
    required this.loading,
    required this.onPrimaryAction,
    required this.onMenuSelected,
    required this.menuItems,
    required this.onTap,
    super.key,
  });

  final String nome;
  final String hora;
  final String countLabel;
  final bool isPublished;
  final String publicBadgeLabel;
  final String? categoryLabel;
  final String? reachLabel;
  final PlaylistTab tab;
  final String saveTooltip;
  final String favoriteOffTooltip;
  final String favoriteOnTooltip;
  final bool expanded;
  final bool loading;
  final VoidCallback onPrimaryAction;
  final ValueChanged<String> onMenuSelected;
  final List<PopupMenuEntry<String>> menuItems;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: switch (tab) {
                      PlaylistTab.unsaved => saveTooltip,
                      PlaylistTab.saved => favoriteOnTooltip,
                      PlaylistTab.favorites => favoriteOffTooltip,
                    },
                    onPressed: loading ? null : onPrimaryAction,
                    icon: Icon(
                      switch (tab) {
                        PlaylistTab.unsaved => Icons.save_outlined,
                        PlaylistTab.saved => Icons.star_outline_rounded,
                        PlaylistTab.favorites => Icons.star_rounded,
                      },
                      color: tab == PlaylistTab.favorites
                          ? AppColors.gold
                          : AppColors.title.withValues(alpha: 0.45),
                      size: 26,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          nome,
                          style: AppTypography.headline.copyWith(
                            fontSize: 17,
                            color: AppColors.title,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isPublished) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Chip(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                avatar: const Icon(
                                  Icons.public,
                                  size: 16,
                                  color: AppColors.gold,
                                ),
                                label: Text(
                                  publicBadgeLabel,
                                  style: AppTypography.label.copyWith(
                                    fontSize: 11,
                                    color: AppColors.title,
                                  ),
                                ),
                                side: const BorderSide(color: AppColors.gold),
                                backgroundColor: AppColors.card,
                              ),
                              if (categoryLabel != null)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  label: Text(
                                    categoryLabel!,
                                    style: AppTypography.label.copyWith(
                                      fontSize: 11,
                                      color: AppColors.title,
                                    ),
                                  ),
                                  side: BorderSide(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  backgroundColor: AppColors.card,
                                ),
                              if (reachLabel != null)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  label: Text(
                                    reachLabel!,
                                    style: AppTypography.label.copyWith(
                                      fontSize: 11,
                                      color: AppColors.title,
                                    ),
                                  ),
                                  side: BorderSide(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  backgroundColor: AppColors.card,
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          hora,
                          style: AppTypography.body.copyWith(
                            fontSize: 13,
                            color: AppColors.title.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          countLabel,
                          style: AppTypography.label.copyWith(
                            fontSize: 12,
                            color: AppColors.title.withValues(alpha: 0.8),
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: loading
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.gold,
                              ),
                            ),
                          )
                        : PopupMenuButton<String>(
                            onSelected: onMenuSelected,
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              color: AppColors.title.withValues(alpha: 0.75),
                            ),
                            color: AppColors.card,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                color: AppColors.gold,
                                width: 1.5,
                              ),
                            ),
                            itemBuilder: (context) => menuItems,
                          ),
                  ),
                ],
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: AppColors.title.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
