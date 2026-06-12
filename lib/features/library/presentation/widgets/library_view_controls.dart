import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'library_pagination_controls.dart';
import 'library_sort_selector.dart';

/// UC-03 — Painel de ordenação e paginação da biblioteca.
///
/// Agrupa [LibrarySortSelector] e [LibraryPaginationControls] num único
/// [GoldenTaggedContainer] (tag [AppLocalizations.libraryViewTitle]) com
/// hierarquia visual consistente com a Home.
///
/// Consumido exclusivamente por [LibraryScreen]. O resumo de resultados
/// ([LibraryResultsSummary]) é renderizado dentro de [LibraryPaginationControls],
/// no mesmo card Visualização.
class LibraryViewControls extends StatelessWidget {
  const LibraryViewControls({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GoldenTaggedContainer(
      label: l10n.libraryViewTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.sortByLabel, style: AppTypography.label),
          const SizedBox(height: 8),
          const LibrarySortSelector(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          const LibraryPaginationControls(),
        ],
      ),
    );
  }
}
