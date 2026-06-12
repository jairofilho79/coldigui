import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_classification.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_special_arrangement_provider.dart';

/// UC-03 — Filtros de arranjo especial (chips dinâmicos do manifest).
///
/// Exclusivo da biblioteca; opções de [libraryAvailableSpecialArrangementsProvider].
class SpecialArrangementFilters extends ConsumerWidget {
  const SpecialArrangementFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final available = ref.watch(libraryAvailableSpecialArrangementsProvider);
    final selected = ref.watch(librarySpecialArrangementProvider.select(
      (state) => state.selectedSpecialArrangements,
    ));

    if (available.isEmpty) return const SizedBox.shrink();

    final sorted = available.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.filtersSpecialArrangementTitle,
          style: AppTypography.label,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final arrangement in sorted)
              FilterChip(
                label: Text(_labelFor(arrangement, l10n)),
                selected: selected.contains(arrangement),
                onSelected: (_) {
                  ref
                      .read(librarySpecialArrangementProvider.notifier)
                      .toggleSpecialArrangement(arrangement);
                },
              ),
          ],
        ),
      ],
    );
  }

  String _labelFor(String arrangement, AppLocalizations l10n) {
    if (arrangement == LouvorClassification.specialArrangementPadrao) {
      return l10n.specialArrangementPadrao;
    }
    return arrangement;
  }
}
