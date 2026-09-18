import 'package:flutter/material.dart';

import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/offline_download_progress.dart';

/// Progresso do download em massa (UC-09, PDF a PDF): uma barra e
/// `{categoria} — done/total PDFs`.
class ProgressSection extends StatelessWidget {
  const ProgressSection({required this.progress, super.key});

  final OfflineDownloadProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress.pdfFraction,
          color: AppColors.gold,
          backgroundColor: AppColors.title.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.offlineProgressDetail(
            progress.currentCategory,
            progress.donePdfs,
            progress.totalPdfs,
            l10n.offlinePhaseFetching,
          ),
          style: AppTypography.body.copyWith(
            color: AppColors.title.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}
