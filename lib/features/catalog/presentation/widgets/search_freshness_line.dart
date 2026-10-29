import 'package:flutter/material.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/home_search_state.dart';

/// Linha «Em cache · a verificar…» → «Atualizado» no topo dos resultados
/// (spec §6.3). Em `failed` o texto é o retry: a lista local já está na
/// tela, não há mais nada a fazer além de tentar de novo.
class SearchFreshnessLine extends StatelessWidget {
  const SearchFreshnessLine({
    required this.freshness,
    required this.newCount,
    this.onRetry,
    super.key,
  });

  final SearchFreshness freshness;
  final int newCount;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = AppColors.textLight.withValues(alpha: 0.7);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    final (icon, text) = switch (freshness) {
      SearchFreshness.checking => (
        Icons.radio_button_unchecked,
        l10n.searchFreshnessChecking,
      ),
      SearchFreshness.updated => (Icons.check, l10n.searchFreshnessUpdated),
      SearchFreshness.updatedWithNew => (
        Icons.check,
        l10n.searchFreshnessUpdatedNew(newCount),
      ),
      SearchFreshness.offline => (
        Icons.radio_button_unchecked,
        l10n.searchFreshnessOffline,
      ),
      SearchFreshness.failed => (
        Icons.radio_button_unchecked,
        l10n.searchFreshnessFailed,
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          if (freshness == SearchFreshness.failed && onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: color,
              ),
              child: Text(text, style: style),
            )
          else
            Text(text, style: style),
        ],
      ),
    );
  }
}
