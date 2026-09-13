import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Largura da zona de seta nas bordas do chip da barra (spec 2026-09-12, D5).
const chipNavZoneWidth = 36.0;

/// Zona de toque «anterior / próximo» dentro do chip — o chip **é** o
/// carrossel.
///
/// Sempre desenhada: nos extremos da lista fica a 35 % e sem `onTap`, para a
/// pessoa saber que é ali que se troca de louvor mesmo quando não dá.
class ChipNavZone extends StatelessWidget {
  const ChipNavZone({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: AppColors.textLight.withValues(alpha: 0.06),
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: chipNavZoneWidth,
              child: Center(
                child: Icon(icon, color: AppColors.card, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
