import '../repositories/catalog_repository.dart';
import '../repositories/manifest_checksum_reader.dart';

/// UC-12 — Poll checksum do manifest ao retornar ao foreground.
///
/// Compara checksum remoto com o último conhecido; em divergência dispara
/// [CatalogRepository.forceRefreshManifest] (que persiste manifest e
/// [CatalogSyncMetadataStore.markSyncedNow]) e salva o novo checksum.
class PollManifestChecksum {
  const PollManifestChecksum(this._repository, this._checksumStore);

  final CatalogRepository _repository;
  final ManifestChecksumReader _checksumStore;

  /// Retorna `true` se o catálogo foi re-sincronizado.
  Future<bool> call() async {
    final remoteChecksum = await _repository.fetchManifestChecksum();
    if (remoteChecksum == null) return false;

    final localChecksum = await _checksumStore.getLastKnownChecksum();
    if (remoteChecksum == localChecksum) return false;

    await _repository.forceRefreshManifest();
    await _checksumStore.saveChecksum(remoteChecksum);
    return true;
  }
}
