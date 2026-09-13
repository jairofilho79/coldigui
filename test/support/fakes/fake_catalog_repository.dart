// test/support/fakes/fake_catalog_repository.dart
//
// Fake compartilhada de [CatalogRepository] (E10) — reúne os comportamentos
// que 4 arquivos de teste reimplementavam: dados fixos (`cached`/`remote`),
// erro configurável para `loadManifest`/`syncManifest`
// (`remoteError`), erro configurável (mutável) para `forceRefreshManifest`
// (`forceRefreshError`), checksum simulado e contadores de chamada.
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/repositories/catalog_repository.dart';

class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    this.cached = const [],
    List<Louvor>? remote,
    this.remoteError,
    this.checksumUnchanged = false,
    this.syncedChecksum,
    this.remoteChecksum,
  }) : remote = remote ?? cached;

  /// Devolvido por [loadCachedLouvores] (enquanto [isarOpen]) e usado como
  /// `remote` quando este não é informado.
  final List<Louvor> cached;

  /// Devolvido por [loadManifest]/[forceRefreshManifest] e como `louvores`
  /// do [ManifestSyncOutcome] quando o checksum muda.
  final List<Louvor> remote;

  /// Lançado por [loadManifest]/[syncManifest] quando não nulo.
  final Object? remoteError;

  /// Lançado por [forceRefreshManifest] quando não nulo — mutável para os
  /// testes que armam o erro depois de construir a fake.
  Object? forceRefreshError;

  /// Simula `/api/catalog/checksum` respondendo 204 (nada mudou).
  final bool checksumUnchanged;

  /// Checksum devolvido pelo sync para o notifier persistir.
  final String? syncedChecksum;

  /// Resposta de `GET /api/catalog/checksum` (`fetchManifestChecksum`).
  final String? remoteChecksum;

  /// `false` enquanto o datasource local é o `unavailable()` do modo degradado.
  var isarOpen = true;

  var loadManifestCalls = 0;
  var forceRefreshCalls = 0;
  var checksumCalls = 0;
  var loadCachedCalls = 0;
  var syncCalls = 0;
  List<Louvor>? lastSyncCached;
  String? lastKnownChecksum;

  @override
  Future<List<Louvor>> loadCachedLouvores() async {
    loadCachedCalls++;
    return isarOpen ? List.of(cached) : const [];
  }

  @override
  Future<List<Louvor>> loadManifest() async {
    loadManifestCalls++;
    if (remoteError != null) throw remoteError!;
    return List.of(remote);
  }

  @override
  Future<List<Louvor>> forceRefreshManifest() async {
    forceRefreshCalls++;
    if (forceRefreshError != null) throw forceRefreshError!;
    return List.of(remote);
  }

  @override
  Future<void> cacheManifest(List<Louvor> louvores) async {}

  @override
  Future<String?> fetchManifestChecksum() async {
    checksumCalls++;
    return remoteChecksum;
  }

  @override
  Future<ManifestSyncOutcome> syncManifest({
    required List<Louvor> cached,
    String? knownChecksum,
  }) async {
    syncCalls++;
    lastSyncCached = cached;
    lastKnownChecksum = knownChecksum;
    if (remoteError != null) throw remoteError!;

    if (checksumUnchanged) {
      return ManifestSyncOutcome(louvores: cached, cacheReplaced: false);
    }

    return ManifestSyncOutcome(
      louvores: List.of(remote),
      cacheReplaced: true,
      checksum: syncedChecksum,
    );
  }

  @override
  Future<bool> isCatalogStale() async => false;
}
