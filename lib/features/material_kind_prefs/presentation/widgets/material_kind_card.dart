import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';

/// Linha de material kind na tela «Materiais favoritos» — mesmo visual do
/// chip de resultado da Pesquisar ([CarouselLouvorChip] retangular): fundo
/// vinho, borda dourada 2px, raio 8, texto branco.
///
/// [leading] fica à esquerda do título (posição do favorito, ícone);
/// [trailing] à direita (×, alça, +). Sem [Material] próprio: quem precisar
/// de ink (arraste em `OverlayEntry`) envolve por fora.
class MaterialKindCard extends StatelessWidget {
  const MaterialKindCard({
    required this.title,
    super.key,
    this.leading,
    this.trailing,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  static const _radius = 8.0;

  @override
  Widget build(BuildContext context) {
    final body = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.headline.copyWith(
                  fontSize: 14,
                  height: 1.1,
                  color: AppColors.textLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTypography.body.copyWith(
                    fontSize: 12,
                    color: AppColors.textLight.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 4), trailing!],
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.title,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: AppColors.shadowMd,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
