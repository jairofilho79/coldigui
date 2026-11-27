import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/offline_reader_material.dart';
import '../providers/offline_maintenance_lock_provider.dart';
import '../providers/reader_offline_provider.dart';

class ReaderOfflineButton extends ConsumerWidget {
  const ReaderOfflineButton({
    required this.material,
    this.style,
    this.color,
    super.key,
  });

  final OfflineReaderMaterial material;
  final ButtonStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    final storageAvailable = ref.watch(isarAvailableProvider);
    final status = ref.watch(readerOfflineAvailableProvider(material));
    final currentEdit = ref.watch(readerOfflineEditProvider);
    final locked = ref.watch(offlineMaintenanceLockProvider) != null;
    final working = currentEdit == material;
    final saved = status.value == true;
    final loading = working || status.isLoading;
    final enabled = storageAvailable && !locked && !loading;

    return IconButton(
      color: color,
      style: style,
      tooltip: !storageAvailable
          ? l10n.offlineStorageUnavailable
          : loading
          ? l10n.readerOfflineWorking
          : status.hasError
          ? l10n.readerOfflineCheckError
          : saved
          ? l10n.readerOfflineSaved
          : l10n.readerOfflineDownload,
      icon: loading
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(
              saved
                  ? Icons.download_done
                  : status.hasError || !storageAvailable
                  ? Icons.cloud_off_outlined
                  : Icons.download_outlined,
            ),
      onPressed: !enabled
          ? null
          : status.hasError
          ? () => ref.invalidate(readerOfflineAvailableProvider(material))
          : () => _changeAvailability(context, ref, l10n, saved),
    );
  }

  Future<void> _changeAvailability(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    bool saved,
  ) async {
    if (saved) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.readerOfflineRemove),
          content: Text(
            material.kind == MaterialKind.lyrics
                ? l10n.readerOfflineRemoveLyrics
                : l10n.readerOfflineRemoveBody,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.readerOfflineConfirmRemove),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    try {
      await ref
          .read(readerOfflineEditProvider.notifier)
          .setAvailable(material, !saved);
    } on Object catch (error) {
      debugPrint('[offline] alteração de ${material.id} falhou: $error');
      if (!context.mounted) return;
      showAppSnackbar(
        context,
        saved ? l10n.readerOfflineRemoveError : l10n.readerOfflineDownloadError,
      );
    }
  }
}
