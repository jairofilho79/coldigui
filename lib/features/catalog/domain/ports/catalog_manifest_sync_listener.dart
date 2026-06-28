import '../../domain/entities/louvor.dart';

/// Notifica substituição do manifest local (antes → depois).
abstract class CatalogManifestSyncListener {
  Future<void> onManifestReplaced({
    required List<Louvor> previousLouvores,
    required List<Louvor> newLouvores,
  });
}
