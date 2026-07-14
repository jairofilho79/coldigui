import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/library/domain/entities/library_catalog_mode.dart';
import 'package:coldigui/features/library/presentation/providers/library_catalog_mode_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chave exclusiva PLPCG | Coldigom no topo da biblioteca.
class LibraryCatalogModeToggle extends ConsumerWidget {
  const LibraryCatalogModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(libraryCatalogModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.libraryCatalogModeLabel,
          style: AppTypography.label.copyWith(color: AppColors.textLight),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _ModeChip(
              label: l10n.libraryCatalogModePlpcg,
              selected: mode == LibraryCatalogMode.plpcg,
              onSelected: () => ref
                  .read(libraryCatalogModeProvider.notifier)
                  .setMode(LibraryCatalogMode.plpcg),
            ),
            _ModeChip(
              label: l10n.libraryCatalogModeColdigom,
              selected: mode == LibraryCatalogMode.coldigom,
              onSelected: () => ref
                  .read(libraryCatalogModeProvider.notifier)
                  .setMode(LibraryCatalogMode.coldigom),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: AppTypography.label.copyWith(
          color: selected ? AppColors.title : AppColors.textLight,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.gold.withValues(alpha: 0.35),
      backgroundColor: AppColors.btnBackground,
      side: BorderSide(
        color: selected
            ? AppColors.gold
            : AppColors.textLight.withValues(alpha: 0.5),
        width: selected ? 2 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      onSelected: (_) => onSelected(),
    );
  }
}
