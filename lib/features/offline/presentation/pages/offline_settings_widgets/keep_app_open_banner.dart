import 'package:flutter/material.dart';

import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../l10n/app_localizations.dart';

/// Aviso para manter o app aberto durante o download em massa (UC-09).
///
/// Extraído de `offline_settings_screen.dart` (E4) — sem mudança de
/// comportamento.
class KeepAppOpenBanner extends StatelessWidget {
  const KeepAppOpenBanner({required this.l10n, super.key});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.title.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.title.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.title.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.offlineKeepAppOpenDuringDownload,
              style: AppTypography.body.copyWith(
                color: AppColors.title.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
