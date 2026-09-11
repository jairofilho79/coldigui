import 'package:flutter/material.dart';

import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../l10n/app_localizations.dart';

/// Banner de checkpoint de download interrompido (UC-09) — retomar ou
/// descartar.
///
/// Extraído de `offline_settings_screen.dart` (E4) — sem mudança de
/// comportamento.
class CheckpointBanner extends StatelessWidget {
  const CheckpointBanner({
    required this.l10n,
    required this.onDismiss,
    required this.onResume,
    super.key,
  });

  final AppLocalizations l10n;
  final VoidCallback onDismiss;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.offlineResumeBanner, style: AppTypography.body),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                child: Text(l10n.offlineDismissCheckpoint),
              ),
              TextButton(
                onPressed: onResume,
                child: Text(l10n.offlineResumeDownload),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
