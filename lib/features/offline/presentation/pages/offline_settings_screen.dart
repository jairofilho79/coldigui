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
import '../../domain/entities/offline_stats.dart';
import '../providers/offline_bulk_download_provider.dart';
import '../providers/offline_cache_status_provider.dart';
import '../providers/offline_category_selection_provider.dart';
import '../providers/offline_mode_provider.dart';
import '../providers/offline_reconcile_provider.dart';
import '../widgets/offline_missing_louvores_sheet.dart';

/// UC-09, UC-10 — Configuração e manutenção do cache offline (Fase 3.7).
class OfflineSettingsScreen extends ConsumerStatefulWidget {
  const OfflineSettingsScreen({super.key});

  @override
  ConsumerState<OfflineSettingsScreen> createState() =>
      _OfflineSettingsScreenState();
}

class _OfflineSettingsScreenState extends ConsumerState<OfflineSettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(offlineReconcileProvider.notifier).requestReconcile();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(offlineBulkDownloadProvider.notifier).pauseForBackground();
    }
  }

  bool get _maintenanceBusy {
    final bulk = ref.watch(offlineBulkDownloadProvider);
    final reconcile = ref.watch(offlineReconcileProvider);
    final cacheStatus = ref.watch(offlineCacheStatusProvider);
    return bulk.isRunning || reconcile.isRunning || cacheStatus.isRefreshing;
  }

  Future<void> _refreshStats() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.offlineRefreshSuccess)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.offlineRefreshError)));
    }
  }

  Future<void> _clearCache() async {
    final l10n = AppLocalizations.of(context)!;
    final materials = ref.read(offlineCategorySelectionProvider).selected;
    final isFullSelection = CatalogMaterials.uiMaterials.every(
      materials.contains,
    );
    final categoriesLabel = _formatSelectedCategories(materials);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.offlineClearCacheConfirmTitle),
        content: Text(
          isFullSelection
              ? l10n.offlineClearCacheConfirmBodyAll
              : l10n.offlineClearCacheConfirmBody(categoriesLabel),
        ),
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

    final wasFullClear = await ref
        .read(clearOfflineCacheProvider)
        .call(materials: materials);

    if (wasFullClear) {
      ref.read(offlineModeProvider.notifier).syncDisabled();
      await ref.read(offlineCategorySelectionProvider.notifier).clearAll();
    } else {
      await ref
          .read(offlineCategorySelectionProvider.notifier)
          .unregisterBulkCompleted(materials);
    }
    ref.read(offlineCacheStatusProvider.notifier).dismissRemovedWarning();
    await ref.read(offlineCacheStatusProvider.notifier).refreshAll();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasFullClear
              ? l10n.offlineClearCacheSuccess
              : l10n.offlineClearCacheSuccessPartial(categoriesLabel),
        ),
      ),
    );
  }

  void _startDownload(List<String> categories) {
    ref.read(offlineBulkDownloadProvider.notifier).start(categories);
  }

  void _showMissingLouvoresForCategory(String material) {
    showOfflineMissingLouvoresSheet(
      context: context,
      ref: ref,
      material: material,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bulkState = ref.watch(offlineBulkDownloadProvider);
    final cacheStatus = ref.watch(offlineCacheStatusProvider);
    final selectionState = ref.watch(offlineCategorySelectionProvider);

    ref.listen(offlineBulkDownloadProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        final message = switch (next.errorMessage) {
          'offlineInsufficientDiskSpace' => l10n.offlineInsufficientDiskSpace,
          'offlineDownloadTimeout' => l10n.offlineDownloadTimeout,
          'offlineDownloadNetworkError' => l10n.offlineDownloadNetworkError,
          _ => l10n.offlineDownloadError,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      if ((next.status == OfflineBulkDownloadStatus.completed ||
              next.status == OfflineBulkDownloadStatus.completedWithWarnings) &&
          previous?.status != next.status) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.offlineDownloadCompleted)));
      }
    });

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          GoldenTaggedContainer(
            label: l10n.offlineStatsTitle,
            child: _OfflineContent(
              cacheStatus: cacheStatus,
              l10n: l10n,
              bulkState: bulkState,
              selectionState: selectionState,
              maintenanceBusy: _maintenanceBusy,
              onDownload: () =>
                  _startDownload(selectionState.selected.toList()),
              onToggleCategory: (material) => ref
                  .read(offlineCategorySelectionProvider.notifier)
                  .toggle(material),
              onCategoryLongPress: _showMissingLouvoresForCategory,
              onClearCache: _clearCache,
              onRefresh: _refreshStats,
              onStopDownload: () =>
                  ref.read(offlineBulkDownloadProvider.notifier).cancel(),
              onDismissCheckpoint: () => ref
                  .read(offlineBulkDownloadProvider.notifier)
                  .dismissCheckpoint(),
              onResumeCheckpoint: () => ref
                  .read(offlineBulkDownloadProvider.notifier)
                  .resumeFromCheckpoint(),
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
                  onPressed: _maintenanceBusy || selectionState.selected.isEmpty
                      ? null
                      : () => _startDownload(selectionState.selected.toList()),
                  child: Text(l10n.offlineDownloadSelected),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

bool _canClearCache(
  OfflineCategorySelectionState selection,
  OfflineStats stats,
) {
  if (selection.selected.isEmpty) return false;
  return selection.selected.any(
    (material) => (stats.byCategory[material] ?? 0) > 0,
  );
}

bool _canDownload(OfflineCategorySelectionState selection) {
  return selection.selected.isNotEmpty;
}

String _formatSelectedCategories(Set<String> selected) {
  return CatalogMaterials.uiMaterials.where(selected.contains).join(', ');
}

int _scopedTotalMissing(OfflineStats stats, Set<String> selected) {
  if (!stats.missingCountReliable) return 0;
  var total = 0;
  for (final material in selected) {
    total += stats.missingByCategory[material] ?? 0;
  }
  return total;
}

bool _categorySupportsLongPress(OfflineStats stats, String material) {
  final downloaded = stats.byCategory[material] ?? 0;
  if (downloaded > 0) return true;
  if (!stats.missingCountReliable) return false;
  return (stats.missingByCategory[material] ?? 0) > 0;
}

class _OfflineContent extends StatelessWidget {
  const _OfflineContent({
    required this.cacheStatus,
    required this.l10n,
    required this.bulkState,
    required this.selectionState,
    required this.maintenanceBusy,
    required this.onDownload,
    required this.onToggleCategory,
    required this.onCategoryLongPress,
    required this.onClearCache,
    required this.onRefresh,
    required this.onStopDownload,
    required this.onDismissCheckpoint,
    required this.onResumeCheckpoint,
  });

  final OfflineCacheStatus cacheStatus;
  final AppLocalizations l10n;
  final OfflineBulkDownloadState bulkState;
  final OfflineCategorySelectionState selectionState;
  final bool maintenanceBusy;
  final VoidCallback onDownload;
  final ValueChanged<String> onToggleCategory;
  final ValueChanged<String> onCategoryLongPress;
  final VoidCallback onClearCache;
  final VoidCallback onRefresh;
  final VoidCallback onStopDownload;
  final VoidCallback onDismissCheckpoint;
  final VoidCallback onResumeCheckpoint;

  String _categoryLabel(String material) {
    final downloaded = cacheStatus.stats.byCategory[material] ?? 0;

    if (!cacheStatus.stats.missingCountReliable) {
      if (downloaded > 0) {
        return l10n.offlineStatsCategoryUnreliableMissing(material, downloaded);
      }
      return l10n.offlineStatsCategory(material, downloaded);
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
    final scopedMissing = _scopedTotalMissing(
      cacheStatus.stats,
      selectionState.selected,
    );
    final canDownload = _canDownload(selectionState);
    final canClearCache = _canClearCache(selectionState, cacheStatus.stats);

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
                  if (selectionState.selected.isNotEmpty &&
                      scopedMissing > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.offlineStatsTotalMissing(scopedMissing),
                      style: AppTypography.body.copyWith(
                        color: AppColors.offlineMissing,
                      ),
                    ),
                  ] else if (!cacheStatus.stats.missingCountReliable &&
                      selectionState.selected.isNotEmpty &&
                      cacheStatus.validCount > 0) ...[
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
        if (bulkState.hasCheckpoint && !bulkState.isRunning) ...[
          const SizedBox(height: 14),
          _CheckpointBanner(
            l10n: l10n,
            onDismiss: onDismissCheckpoint,
            onResume: onResumeCheckpoint,
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final material in CatalogMaterials.uiMaterials)
              _CategoryFilterChip(
                label: _categoryLabel(material),
                selected: selectionState.selected.contains(material),
                enabled: !maintenanceBusy,
                onSelected: (_) => onToggleCategory(material),
                onLongPress:
                    _categorySupportsLongPress(cacheStatus.stats, material)
                    ? () => onCategoryLongPress(material)
                    : null,
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed:
                    maintenanceBusy || !canDownload || bulkState.isRunning
                    ? null
                    : onDownload,
                child: Text(l10n.offlineDownloadSelected),
              ),
            ),
            if (bulkState.isRunning) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onStopDownload,
                child: Text(l10n.offlineStopDownload),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: maintenanceBusy || !canClearCache ? null : onClearCache,
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

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onSelected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final chip = FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.gold.withValues(alpha: 0.3),
      backgroundColor: AppColors.card,
      side: BorderSide(
        color: selected
            ? AppColors.gold
            : AppColors.title.withValues(alpha: 0.4),
        width: selected ? 2 : 1.5,
      ),
      onSelected: enabled ? onSelected : null,
    );

    if (onLongPress == null || !enabled) return chip;

    return GestureDetector(onLongPress: onLongPress, child: chip);
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

    final hasZipProgress =
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
          l10n.offlineProgressDetail(
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
