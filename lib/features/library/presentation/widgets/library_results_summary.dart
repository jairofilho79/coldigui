import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_group_results_provider.dart';

/// UC-03 — Indicador textual de resultados filtrados e paginados.
///
/// Observa [libraryGroupResultsProvider] e exibe [AppLocalizations.libraryResultsSummary]
/// com intervalo `{from}–{to}` da página atual, ou [AppLocalizations.libraryResultsEmpty]
/// quando nenhum louvor corresponde aos filtros — esta só com o índice
/// pronto: a carregar ou em erro, «nenhum louvor encontrado» seria falso (a
/// tela já mostra o skeleton ou `catalogLoadError`).
///
/// Consumido por [LibraryPaginationControls] dentro do card Visualização.
/// Usa [AppTypography.body] para legibilidade sobre fundo creme.
class LibraryResultsSummary extends ConsumerWidget {
  const LibraryResultsSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final results = ref.watch(libraryGroupResultsProvider);

    if (results.totalItems == 0) {
      if (ref.watch(catalogIndexStatusProvider) != CatalogIndexStatus.ready) {
        return const SizedBox.shrink();
      }
      return Text(
        l10n.libraryResultsEmpty,
        style: AppTypography.body,
        textAlign: TextAlign.center,
      );
    }

    final from = (results.page - 1) * results.itemsPerPage + 1;
    final to = results.page * results.itemsPerPage;
    final clampedTo = to > results.totalItems ? results.totalItems : to;

    return Text(
      l10n.libraryResultsSummary(from, clampedTo, results.totalItems),
      style: AppTypography.body,
      textAlign: TextAlign.center,
    );
  }
}
