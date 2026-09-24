import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/golden_tagged_container.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/offline_cache_status_provider.dart';
import '../providers/offline_coldigom_download_provider.dart';
import '../providers/offline_maintenance_lock_provider.dart';
import '../providers/offline_reconcile_provider.dart';
import 'offline_settings_widgets/coldigom_section.dart';

/// UC-09, UC-10 — `/offline` com uma secção só (spec 2026-09-23 §3.1).
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
      ref.read(offlineColdigomDownloadProvider.notifier).pauseForBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cacheStatus = ref.watch(offlineCacheStatusProvider);
    final busy = ref.watch(offlineMaintenanceLockProvider) != null;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          GoldenTaggedContainer(
            label: l10n.offlineSectionTitle,
            child: const ColdigomOfflineSection(),
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
                  onPressed: busy
                      ? null
                      : () => ref
                            .read(offlineCacheStatusProvider.notifier)
                            .dismissRemovedWarning(),
                  child: Text(l10n.offlineDismissRemoved),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
