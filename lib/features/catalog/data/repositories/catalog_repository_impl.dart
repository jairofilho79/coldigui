import '../../domain/entities/louvor.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_local_datasource.dart';
import '../datasources/catalog_remote_datasource.dart';
import '../datasources/catalog_sync_metadata_store.dart';

/// Implementação de [CatalogRepository] — orquestra remote + local (UC-12).
///
/// Fluxo: tenta rede → persiste em Isar; em falha ou resposta vazia usa cache local.
class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl({
    required CatalogRemoteDatasource remote,
    required CatalogLocalDatasource local,
    required CatalogSyncMetadataStore syncMetadata,
  })  : _remote = remote,
        _local = local,
        _syncMetadata = syncMetadata;

  final CatalogRemoteDatasource _remote;
  final CatalogLocalDatasource _local;
  final CatalogSyncMetadataStore _syncMetadata;

  @override
  Future<List<Louvor>> loadManifest() async {
    try {
      final remoteLouvores = await _remote.fetchManifest();

      if (remoteLouvores.isEmpty) {
        final cached = await _local.loadLouvores();
        if (cached.isNotEmpty) return cached;
        return remoteLouvores;
      }

      await cacheManifest(remoteLouvores);
      await _syncMetadata.markSyncedNow();
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

    await cacheManifest(remoteLouvores);
    await _syncMetadata.markSyncedNow();
    return remoteLouvores;
  }

  @override
  Future<void> cacheManifest(List<Louvor> louvores) =>
      _local.saveLouvores(louvores);

  @override
  Future<String?> fetchManifestChecksum() => _remote.fetchChecksum();

  @override
  Future<bool> isCatalogStale() => _syncMetadata.isStale();
}
