import '../../domain/entities/louvor.dart';
import '../../domain/ports/catalog_manifest_sync_listener.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_local_datasource.dart';
import '../datasources/catalog_remote_datasource.dart';
import '../datasources/catalog_sync_metadata_store.dart';

/// Implementação de [CatalogRepository] — orquestra remote + local (UC-12).
///
/// Fluxo: tenta rede → persiste em Isar; em falha ou resposta vazia usa cache local.
class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl({
    required this._remote,
    required this._local,
    required this._syncMetadata,
    this._manifestSyncListener,
  });

  final CatalogRemoteDatasource _remote;
  final CatalogLocalDatasource _local;
  final CatalogSyncMetadataStore _syncMetadata;
  final CatalogManifestSyncListener? _manifestSyncListener;

  @override
  Future<List<Louvor>> loadManifest() async {
    try {
      final remoteLouvores = await _remote.fetchManifest();

      if (remoteLouvores.isEmpty) {
        final cached = await _local.loadLouvores();
        if (cached.isNotEmpty) return cached;
        return remoteLouvores;
      }

      final previousLouvores = await _local.loadLouvores();
      await cacheManifest(remoteLouvores);
      await _syncMetadata.markSyncedNow();
      await _notifyManifestReplaced(previousLouvores, remoteLouvores);
      return remoteLouvores;
    } on Object {
      final cached = await _local.loadLouvores();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  @override
  Future<List<Louvor>> forceRefreshManifest() async {
    final remoteLouvores = await _remote.fetchManifest();

    if (remoteLouvores.isEmpty) {
      throw StateError('Manifest remoto vazio');
    }

    final previousLouvores = await _local.loadLouvores();
    await cacheManifest(remoteLouvores);
    await _syncMetadata.markSyncedNow();
    await _notifyManifestReplaced(previousLouvores, remoteLouvores);
    return remoteLouvores;
  }

  Future<void> _notifyManifestReplaced(
    List<Louvor> previousLouvores,
    List<Louvor> newLouvores,
  ) async {
    final listener = _manifestSyncListener;
    if (listener == null || previousLouvores.isEmpty) return;
    await listener.onManifestReplaced(
      previousLouvores: previousLouvores,
      newLouvores: newLouvores,
    );
  }

  @override
  Future<void> cacheManifest(List<Louvor> louvores) =>
      _local.saveLouvores(louvores);

  @override
  Future<String?> fetchManifestChecksum() => _remote.fetchChecksum();

  @override
  Future<bool> isCatalogStale() => _syncMetadata.isStale();
}
