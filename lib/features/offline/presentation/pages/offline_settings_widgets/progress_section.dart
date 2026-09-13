import 'package:flutter/material.dart';

import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../core/utils/byte_format.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/offline_download_progress.dart';

/// Progresso do download em massa (UC-09): fase, PDFs concluídos e, quando
/// há ZIP, bytes recebidos.
///
/// Extraído de `offline_settings_screen.dart` (E4) — sem mudança de
/// comportamento.
class ProgressSection extends StatelessWidget {
  const ProgressSection({required this.progress, super.key});

  final OfflineDownloadProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPdfOnlyProgress = progress.totalParts == 0;
    final phaseLabel = isPdfOnlyProgress
        ? switch (progress.phase) {
            OfflineDownloadPhase.syncing => l10n.offlinePhaseSyncing,
            _ => l10n.offlinePhaseFetching,
          }
        : switch (progress.phase) {
            OfflineDownloadPhase.fetching => l10n.offlinePhaseFetching,
            OfflineDownloadPhase.extracting => l10n.offlinePhaseExtracting,
            OfflineDownloadPhase.storing => l10n.offlinePhaseStoring,
            OfflineDownloadPhase.syncing => l10n.offlinePhaseSyncing,
          };

    final hasZipProgress =
        !isPdfOnlyProgress &&
        progress.zipBytesReceived != null &&
        progress.zipBytesTotal != null &&
        progress.zipBytesTotal! > 0;

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
          isPdfOnlyProgress
              ? l10n.offlineProgressDetailWeb(
                  progress.currentCategory,
                  progress.donePdfs,
                  progress.totalPdfs,
                  phaseLabel,
                )
              : l10n.offlineProgressDetail(
                  progress.currentCategory,
                  progress.currentPart,
                  progress.totalParts,
                  progress.donePdfs,
                  progress.totalPdfs,
                  phaseLabel,
                ),
          style: AppTypography.body.copyWith(
            color: AppColors.title.withValues(alpha: 0.75),
          ),
        ),
        if (hasZipProgress) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.zipFraction,
            color: AppColors.gold,
            backgroundColor: AppColors.title.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.offlineFetchProgress(
              progress.currentPart,
              progress.totalParts,
              formatCompactBytes(progress.zipBytesReceived!),
              formatCompactBytes(progress.zipBytesTotal!),
            ),
            style: AppTypography.body.copyWith(
              color: AppColors.title.withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    );
  }
}
