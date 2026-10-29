import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

import 'carousel_bar_shell.dart';

/// Botão da barra da lista ativa: ícone em cima, legenda embaixo (spec
/// 2026-09-12, D3). Em barra estreita ([showLabel] `false`) vira o
/// [IconButton] de sempre, com a legenda como tooltip.
///
/// A legenda existe porque os ícones da barra são conceitos próprios do app
/// («Material», «Lista») — texto ganha de metáfora para quem chega agora.
class CarouselBarActionButton extends StatelessWidget {
  const CarouselBarActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.showLabel = true,
    this.iconOverride,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Tooltip do modo sem legenda — default [label].
  final String? tooltip;
  final bool showLabel;

  /// Substitui o ícone (ex.: spinner enquanto compartilha).
  final Widget? iconOverride;

  @override
  Widget build(BuildContext context) {
    final iconWidget = iconOverride ?? Icon(icon, size: 22);

    if (!showLabel) {
      return IconButton(
        style: carouselBarIconButtonStyle,
        tooltip: tooltip ?? label,
        icon: iconWidget,
        onPressed: onPressed,
      );
    }

    final button = TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.title,
        disabledForegroundColor: AppColors.title.withValues(alpha: 0.38),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(54, 50),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );

    // Só quando [tooltip] existe (ex.: «Limpar», cuja legenda curta não diz
    // "seleção" sozinha, spec §7) — «Abrir»/«Lista» já são autoexplicativos
    // com a legenda visível e não ganham tooltip redundante.
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Grupo de botões por escopo (louvor / lista): fundo tintado leve que diz
/// «estes agem sobre a mesma coisa» sem gastar altura com rótulo (spec D2).
class CarouselBarActionGroup extends StatelessWidget {
  const CarouselBarActionGroup({
    required this.children,
    required this.tint,
    super.key,
  });

  final List<Widget> children;
  final Color tint;

  /// Tinta do grupo «louvor».
  static Color get louvorTint => AppColors.title.withValues(alpha: 0.08);

  /// Tinta do grupo «lista».
  static Color get listaTint => AppColors.gold.withValues(alpha: 0.18);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Divisor entre grupos.
class CarouselBarGroupDivider extends StatelessWidget {
  const CarouselBarGroupDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.title.withValues(alpha: 0.38),
    );
  }
}
