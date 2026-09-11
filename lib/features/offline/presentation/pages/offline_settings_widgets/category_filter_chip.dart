import 'package:flutter/material.dart';

import '../../../../../core/theme/color_extensions.dart';

/// Chip de filtro por categoria (UC-09) — seleção múltipla, toque longo abre
/// os louvores faltantes daquela categoria.
///
/// Extraído de `offline_settings_screen.dart` (E4) — sem mudança de
/// comportamento.
class CategoryFilterChip extends StatelessWidget {
  const CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    this.onLongPress,
    super.key,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onSelected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final chip = FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.gold.withValues(alpha: 0.3),
      backgroundColor: AppColors.card,
      side: BorderSide(
        color: selected
            ? AppColors.gold
            : AppColors.title.withValues(alpha: 0.4),
        width: selected ? 2 : 1.5,
      ),
      onSelected: enabled ? onSelected : null,
    );

    if (onLongPress == null || !enabled) return chip;

    return GestureDetector(onLongPress: onLongPress, child: chip);
  }
}
