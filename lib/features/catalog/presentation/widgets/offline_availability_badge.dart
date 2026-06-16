import 'package:flutter/material.dart';

import '../../../pdf_opening/domain/entities/pdf_offline_availability.dart';
import '../../../../l10n/app_localizations.dart';

/// Ícone de disponibilidade offline no catálogo — permanente vs cache LRU.
class OfflineAvailabilityBadge extends StatelessWidget {
  const OfflineAvailabilityBadge({
    required this.availability,
    super.key,
  });

  final PdfOfflineAvailability availability;

  @override
  Widget build(BuildContext context) {
    return switch (availability) {
      PdfOfflineAvailability.notAvailable => const SizedBox.shrink(),
      PdfOfflineAvailability.persistentOffline => Tooltip(
          message: AppLocalizations.of(context)?.pdfOfflinePersistentTooltip ??
              'Disponível offline',
          child: Icon(
            Icons.cloud_done,
            size: 14,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      PdfOfflineAvailability.cachedLru => Tooltip(
          message: AppLocalizations.of(context)?.pdfOfflineCachedLruTooltip ??
              'Cache temporário — pode ser removido',
          child: Icon(
            Icons.cloud_done,
            size: 14,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
    };
  }
}
