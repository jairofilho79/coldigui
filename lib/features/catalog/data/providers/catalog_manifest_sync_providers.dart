import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../carousel/data/providers/carousel_providers.dart';
import '../../../offline/data/listeners/offline_catalog_manifest_sync_listener.dart';
import '../../../offline/data/providers/offline_repository_providers.dart';
import '../../../offline/domain/usecases/remap_pdf_ids_after_catalog_update.dart';
import '../../../playlists/data/providers/playlist_providers.dart';
import '../../domain/ports/catalog_manifest_sync_listener.dart';

/// Listener pós-sync do manifest — remapeia pdfIds obsoletos.
final catalogManifestSyncListenerProvider =
    Provider<CatalogManifestSyncListener>((ref) {
  return OfflineCatalogManifestSyncListener(
    RemapPdfIdsAfterCatalogUpdate(
      ref.watch(offlinePdfRepositoryProvider),
      ref.watch(playlistRepositoryProvider),
      ref.watch(carouselRepositoryProvider),
    ),
  );
});
