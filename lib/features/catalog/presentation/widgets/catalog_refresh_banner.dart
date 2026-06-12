import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/catalog_refresh_provider.dart';

/// Banner UC-12 — refresh manual do catálogo na biblioteca (Fase 1.5).
///
/// Renderizado em [GoldenTaggedContainer] com tag [AppLocalizations.catalogRefreshLabel].
/// Expõe [Key] `catalogRefreshBanner` no container para widget tests.
/// Observa [catalogRefreshProvider] para loading, erro e ação de refresh.
class CatalogRefreshBanner extends ConsumerWidget {
  const CatalogRefreshBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final refreshState = ref.watch(catalogRefreshProvider);

    return GoldenTaggedContainer(
      key: const Key('catalogRefreshBanner'),
      label: l10n.catalogRefreshLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.catalogRefreshMessage,
            style: AppTypography.body,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.btnBackground,
                foregroundColor: AppColors.textLight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: refreshState.isLoading
                  ? null
                  : () => ref.read(catalogRefreshProvider.notifier).refresh(),
              child: refreshState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textLight,
                      ),
                    )
                  : Text(l10n.catalogRefreshAction),
            ),
          ),
          if (refreshState.hasError) ...[
            const SizedBox(height: 8),
            Text(
              l10n.catalogRefreshError,
              style: AppTypography.body.copyWith(
                color: AppColors.offlineMissing,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
