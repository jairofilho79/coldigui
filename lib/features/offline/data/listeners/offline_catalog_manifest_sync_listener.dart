import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/ports/catalog_manifest_sync_listener.dart';
import '../../domain/usecases/remap_pdf_ids_after_catalog_update.dart';

/// Dispara remapeamento offline/playlists/carousel após sync do manifest.
class OfflineCatalogManifestSyncListener
    implements CatalogManifestSyncListener {
  const OfflineCatalogManifestSyncListener(this._remapPdfIds);

  final RemapPdfIdsAfterCatalogUpdate _remapPdfIds;

  @override
  Future<void> onManifestReplaced({
    required List<Louvor> previousLouvores,
    required List<Louvor> newLouvores,
  }) =>
      _remapPdfIds(
        previousLouvores: previousLouvores,
        newLouvores: newLouvores,
      );
}
