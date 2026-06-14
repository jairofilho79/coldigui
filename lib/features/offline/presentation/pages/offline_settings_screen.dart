import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/byte_format.dart';
import '../../../../core/widgets/golden_tagged_container.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/domain/constants/catalog_materials.dart';
import '../../data/providers/offline_providers.dart';
import '../../domain/entities/offline_download_progress.dart';
import '../providers/offline_bulk_download_provider.dart';
import '../providers/offline_cache_status_provider.dart';
import '../providers/offline_missing_download_provider.dart';
import '../providers/offline_mode_provider.dart';
import '../providers/offline_reconcile_provider.dart';

/// UC-09, UC-10 — Configuração e manutenção do cache offline (Fase 3.7).
///
/// Layout com **um** [GoldenTaggedContainer] por vez (§5.2 MAPEAMENTO), gated por
/// [offlineModeProvider] (`OFFLINE_AVAILABLE=TRUE` após UC-09):
///
/// - **UC-09** ([offlineSelectCategories]): seleção de categorias, bulk ZIP,
///   checkpoint e [offlineDownloadSelected].
/// - **UC-10** ([offlineStatsTitle]): stats, [offlineMissingDownloadProvider],
///   baixar faltantes e limpar cache.
///
/// Providers: [offlineCacheStatusProvider], [offlineReconcileProvider] (reconcile
/// no `initState` pós-frame), [offlineMissingDownloadProvider],
/// [offlineBulkDownloadProvider]. Banners de aviso (PDFs removidos) usam
/// [AppColors.card] para contraste sobre o scaffold.
class OfflineSettingsScreen extends ConsumerStatefulWidget {
  const OfflineSettingsScreen({super.key});

  @override
  ConsumerState<OfflineSettingsScreen> createState() =>
      _OfflineSettingsScreenState();
}

class _OfflineSettingsScreenState extends ConsumerState<OfflineSettingsScreen> {
  final _selectedCategories = <String>{
    ...CatalogMaterials.defaultSelected,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(offlineReconcileProvider.notifier).requestReconcile();
    });
  }

  bool get _maintenanceBusy {
    final bulk = ref.watch(offlineBulkDownloadProvider);
    final missing = ref.watch(offlineMissingDownloadProvider);
    final reconcile = ref.watch(offlineReconcileProvider);
    final cacheStatus = ref.watch(offlineCacheStatusProvider);
    return bulk.isRunning ||
        missing.isRunning ||
        reconcile.isRunning ||
        cacheStatus.isRefreshing;
  }

  Future<void> _refreshStats() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.offlineRefreshSuccess)),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.offlineRefreshError)),
      );
    }
  }

  Future<void> _clearCache() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.offlineClearCacheConfirmTitle),
        content: Text(l10n.offlineClearCacheConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.offlineClearCacheCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.offlineClearCacheConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref.read(clearOfflineCacheProvider).call();
    ref.read(offlineModeProvider.notifier).syncDisabled();
    ref.read(offlineCacheStatusProvider.notifier).dismissRemovedWarning();
    await ref.read(offlineCacheStatusProvider.notifier).refresh();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.offlineClearCacheSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bulkState = ref.watch(offlineBulkDownloadProvider);
    final cacheStatus = ref.watch(offlineCacheStatusProvider);
    final missingState = ref.watch(offlineMissingDownloadProvider);
    final isMaintenanceMode = ref.watch(offlineModeProvider);
    final showMaintenance = isMaintenanceMode && !bulkState.isRunning;
    final showBulkSetup = !showMaintenance;

    ref.listen(offlineBulkDownloadProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        final message = switch (next.errorMessage) {
          'offlineInsufficientDiskSpace' => l10n.offlineInsufficientDiskSpace,
          'offlineDownloadTimeout' => l10n.offlineDownloadTimeout,
          'offlineDownloadNetworkError' => l10n.offlineDownloadNetworkError,
          _ => l10n.offlineDownloadError,
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      if (next.status == OfflineBulkDownloadStatus.completed &&
          previous?.status != OfflineBulkDownloadStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.offlineDownloadCompleted)),
        );
      }
    });

    ref.listen(offlineMissingDownloadProvider, (previous, next) {
      if (next.status == OfflineMissingDownloadStatus.completed &&
          previous?.status != OfflineMissingDownloadStatus.completed &&
          next.lastResult != null) {
        final result = next.lastResult!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.offlineMissingCompleted(
              result.downloadedCount,
              result.failedCount,
            )),
          ),
        );
      }
      if (next.status == OfflineMissingDownloadStatus.failed &&
          previous?.status != OfflineMissingDownloadStatus.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.offlineMissingError)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.offlineTitle),
        actions: [
          IconButton(
            onPressed: _maintenanceBusy ? null : _refreshStats,
            tooltip: l10n.offlineRefreshStats,
            icon: cacheStatus.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (showMaintenance) ...[
            GoldenTaggedContainer(
              label: l10n.offlineStatsTitle,
              child: _StatsSection(
                cacheStatus: cacheStatus,
                l10n: l10n,
                missingState: missingState,
                maintenanceBusy: _maintenanceBusy,
                onDownloadMissing: () =>
                    ref.read(offlineMissingDownloadProvider.notifier).start(),
                onClearCache: _clearCache,
                onRefresh: _refreshStats,
              ),
            ),
            if (cacheStatus.showRemovedWarning) ...[
              const SizedBox(height: 12),
              MaterialBanner(
                backgroundColor: AppColors.card,
                content: Text(
                  l10n.offlineRemovedBanner(cacheStatus.removedCount),
                  style: AppTypography.body,
                ),
                actions: [
                  TextButton(
                    onPressed: _maintenanceBusy
                        ? null
                        : () => ref
                            .read(offlineCacheStatusProvider.notifier)
                            .dismissRemovedWarning(),
                    child: Text(l10n.offlineDismissRemoved),
                  ),
                  TextButton(
                    onPressed: _maintenanceBusy
                        ? null
                        : () => ref
                            .read(offlineMissingDownloadProvider.notifier)
                            .start(),
                    child: Text(l10n.offlineDownloadMissing),
                  ),
                ],
              ),
            ],
          ],
          if (showBulkSetup) ...[
            GoldenTaggedContainer(
              label: l10n.offlineSelectCategories,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (bulkState.hasCheckpoint && !bulkState.isRunning) ...[
                    _CheckpointBanner(
                      l10n: l10n,
                      onDismiss: () => ref
                          .read(offlineBulkDownloadProvider.notifier)
                          .dismissCheckpoint(),
                      onResume: () => ref
                          .read(offlineBulkDownloadProvider.notifier)
                          .resumeFromCheckpoint(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final material in CatalogMaterials.uiMaterials)
                        FilterChip(
                          label: Text(material),
                          selected: _selectedCategories.contains(material),
                          showCheckmark: false,
                          selectedColor: AppColors.gold.withValues(alpha: 0.3),
                          backgroundColor: AppColors.card,
                          side: BorderSide(
                            color: _selectedCategories.contains(material)
                                ? AppColors.gold
                                : AppColors.title.withValues(alpha: 0.4),
                            width: _selectedCategories.contains(material)
                                ? 2
                                : 1.5,
                          ),
                          onSelected: bulkState.isRunning
                              ? null
                              : (_) {
                                  setState(() {
                                    if (_selectedCategories
                                        .contains(material)) {
                                      _selectedCategories.remove(material);
                                    } else {
                                      _selectedCategories.add(material);
                                    }
                                  });
                                },
                        ),
                    ],
                  ),
                  if (bulkState.isRunning) ...[
                    const SizedBox(height: 16),
                    _KeepAppOpenBanner(l10n: l10n),
                  ],
                  if (bulkState.isRunning && bulkState.progress != null) ...[
                    const SizedBox(height: 12),
                    _ProgressSection(progress: bulkState.progress!),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: bulkState.isRunning ||
                                  _selectedCategories.isEmpty
                              ? null
                              : () => ref
                                  .read(offlineBulkDownloadProvider.notifier)
                                  .start(_selectedCategories.toList()),
                          child: Text(l10n.offlineDownloadSelected),
                        ),
                      ),
                      if (bulkState.isRunning) ...[
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => ref
                              .read(offlineBulkDownloadProvider.notifier)
                              .cancel(),
                          child: Text(l10n.offlineCancelDownload),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.cacheStatus,
    required this.l10n,
    required this.missingState,
    required this.maintenanceBusy,
    required this.onDownloadMissing,
    required this.onClearCache,
    required this.onRefresh,
  });

  final OfflineCacheStatus cacheStatus;
  final AppLocalizations l10n;
  final OfflineMissingDownloadState missingState;
  final bool maintenanceBusy;
  final VoidCallback onDownloadMissing;
  final VoidCallback onClearCache;
  final VoidCallback onRefresh;

  String _categoryLabel(String material) {
    final downloaded = cacheStatus.stats.byCategory[material] ?? 0;
    if (!cacheStatus.stats.missingCountReliable) {
      return l10n.offlineStatsCategoryUnreliableMissing(material, downloaded);
    }
    final missing = cacheStatus.stats.missingByCategory[material] ?? 0;
    if (missing > 0) {
      return l10n.offlineStatsCategoryWithMissing(
        material,
        downloaded,
        missing,
      );
    }
    return l10n.offlineStatsCategory(material, downloaded);
  }

  String _diskUsageLabel() {
    final used = formatCompactBytes(cacheStatus.stats.totalDiskUsageBytes);
    final freeBytes = cacheStatus.freeDiskBytes;
    if (freeBytes == null) {
      return l10n.offlineStatsDiskUsageUsedOnly(used);
    }
    final free = formatCompactBytes(freeBytes);
    return l10n.offlineStatsDiskUsage(used, free);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.offlineStatsTotal(cacheStatus.validCount),
                    style: AppTypography.headline.copyWith(fontSize: 18),
                  ),
                  if (cacheStatus.stats.totalMissing > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.offlineStatsTotalMissing(
                        cacheStatus.stats.totalMissing,
                      ),
                      style: AppTypography.body.copyWith(
                        color: AppColors.offlineMissing,
                      ),
                    ),
                  ] else if (!cacheStatus.stats.missingCountReliable) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.offlineStatsMissingUnreliable,
                      style: AppTypography.body.copyWith(
                        color: AppColors.title.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _diskUsageLabel(),
                    style: AppTypography.body.copyWith(
                      color: AppColors.title.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            if (cacheStatus.isRefreshing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton.icon(
                onPressed: maintenanceBusy ? null : onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.offlineRefreshStats),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final material in CatalogMaterials.uiMaterials)
              _StatChip(label: _categoryLabel(material)),
          ],
        ),
        if (missingState.isRunning && missingState.total > 0) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: missingState.done / missingState.total,
            color: AppColors.gold,
            backgroundColor: AppColors.title.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.offlineMissingProgress(
              missingState.done,
              missingState.total,
            ),
            style: AppTypography.body.copyWith(
              color: AppColors.title.withValues(alpha: 0.75),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: maintenanceBusy ? null : onDownloadMissing,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.title,
            side: const BorderSide(color: AppColors.title, width: 1.5),
          ),
          child: Text(l10n.offlineDownloadMissing),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: maintenanceBusy ? null : onClearCache,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.offlineMissing,
            ),
            child: Text(l10n.offlineClearCache),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: Text(label, style: AppTypography.label),
    );
  }
}

class _KeepAppOpenBanner extends StatelessWidget {
  const _KeepAppOpenBanner({required this.l10n});

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

class _CheckpointBanner extends StatelessWidget {
  const _CheckpointBanner({
    required this.l10n,
    required this.onDismiss,
    required this.onResume,
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
                  child: Text(l10n.offlineDismissCheckpoint)),
              TextButton(
                  onPressed: onResume, child: Text(l10n.offlineResumeDownload)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.progress});

  final OfflineDownloadProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final phaseLabel = switch (progress.phase) {
      OfflineDownloadPhase.fetching => l10n.offlinePhaseFetching,
      OfflineDownloadPhase.extracting => l10n.offlinePhaseExtracting,
      OfflineDownloadPhase.storing => l10n.offlinePhaseStoring,
      OfflineDownloadPhase.syncing => l10n.offlinePhaseSyncing,
    };

    final isFetching = progress.phase == OfflineDownloadPhase.fetching;
    final hasZipProgress = isFetching &&
        progress.zipBytesReceived != null &&
        progress.zipBytesTotal != null &&
        progress.zipBytesTotal! > 0;
    final fraction =
        hasZipProgress ? progress.zipFraction : progress.pdfFraction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: fraction,
          color: AppColors.gold,
          backgroundColor: AppColors.title.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 8),
        Text(
          hasZipProgress
              ? l10n.offlineFetchProgress(
                  progress.currentPart,
                  progress.totalParts,
                  formatCompactBytes(progress.zipBytesReceived!),
                  formatCompactBytes(progress.zipBytesTotal!),
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
      ],
    );
  }
}
