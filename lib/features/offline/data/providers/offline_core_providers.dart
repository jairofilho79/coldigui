import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../../pdf_opening/domain/usecases/validate_pdf_availability.dart';
import '../../../playlists/data/providers/playlist_providers.dart';
import '../../domain/usecases/fetch_and_store_pdf.dart';
import '../../domain/usecases/migrate_offline_storage.dart';
import '../../domain/usecases/reconcile_offline_index.dart';
import '../../domain/usecases/resolve_pdf_for_reader.dart';
import '../datasources/favorite_pdf_ids_resolver.dart';
import 'offline_repository_providers.dart';

export 'offline_repository_providers.dart';

/// DI — [FetchAndStorePdf] (Fase 3.3).
final fetchAndStorePdfProvider = Provider<FetchAndStorePdf>((ref) {
  return FetchAndStorePdf(
    ref.watch(pdfBytesDatasourceProvider),
    ref.watch(offlinePdfRepositoryProvider),
    favoritePdfIdsResolver: ref.watch(favoritePdfIdsResolverProvider),
  );
});

/// DI — [ResolvePdfForReader] (Fase 3.2 + 3.3 + 3.4).
final resolvePdfForReaderProvider = Provider<ResolvePdfForReader>((ref) {
  return ResolvePdfForReader(
    ref.watch(offlinePdfRepositoryProvider),
    ref.watch(fetchAndStorePdfProvider),
  );
});

/// DI — [ValidatePdfAvailability] (Fase 3.4).
final validatePdfAvailabilityProvider = Provider<ValidatePdfAvailability>((
  ref,
) {
  return ValidatePdfAvailability(ref.watch(offlinePdfRepositoryProvider));
});

/// DI — PDFs em playlists favoritas (protegidos da eviction LRU).
final favoritePdfIdsResolverProvider = Provider<FavoritePdfIdsResolver>((ref) {
  return FavoritePdfIdsResolver(ref.watch(playlistLocalDatasourceProvider));
});

/// DI — [ReconcileOfflineIndex] mínimo (Fase 3.5).
final reconcileOfflineIndexProvider = Provider<ReconcileOfflineIndex>((ref) {
  return ReconcileOfflineIndex(
    ref.watch(offlinePdfRepositoryProvider),
    ref.watch(pdfStoragePortProvider),
  );
});

/// DI — [MigrateOfflineStorage] (Fase 3.6).
final migrateOfflineStorageProvider = Provider<MigrateOfflineStorage>((ref) {
  return MigrateOfflineStorage(
    ref.watch(sharedPreferencesProvider),
    ref.watch(offlinePdfLocalDatasourceProvider),
    ref.watch(pdfStoragePortProvider),
  );
});
