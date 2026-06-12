import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_view_settings_provider.dart';

/// UC-03 — Seletor de ordenação (número ou nome).
///
/// [SegmentedButton] estilizado com paleta gold/title (§6).
/// Persiste escolha via [libraryViewSettingsProvider.setSortBy].
class LibrarySortSelector extends ConsumerWidget {
  const LibrarySortSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sortBy = ref.watch(libraryViewSettingsProvider.select(
      (state) => state.sortBy,
    ));

    return SegmentedButton<String>(
      style: SegmentedButton.styleFrom(
        textStyle: AppTypography.label,
        selectedBackgroundColor: AppColors.gold.withValues(alpha: 0.3),
        selectedForegroundColor: AppColors.title,
        foregroundColor: AppColors.title,
        side: const BorderSide(color: AppColors.gold, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      segments: [
        ButtonSegment(
          value: 'numero',
          label: Text(l10n.sortByNumber),
        ),
        ButtonSegment(
          value: 'nome',
          label: Text(l10n.sortByName),
        ),
      ],
      selected: {sortBy},
      onSelectionChanged: (selection) {
        ref
            .read(libraryViewSettingsProvider.notifier)
            .setSortBy(selection.first);
      },
    );
  }
}
