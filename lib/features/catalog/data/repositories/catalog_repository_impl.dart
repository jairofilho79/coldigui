import 'package:flutter/foundation.dart';

import '../../domain/entities/louvor.dart';
import '../../domain/ports/catalog_manifest_sync_listener.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_local_datasource.dart';
import '../datasources/catalog_remote_datasource.dart';
import '../datasources/catalog_sync_metadata_store.dart';

/// Implementação de [CatalogRepository] — orquestra remote + local (UC-12).
///
/// Fluxo: tenta rede → persiste em Isar; em falha ou resposta vazia usa cache local.
/// [syncManifest] adiciona dois curto-circuitos (A1): checksum inalterado dispensa
/// o download, e manifest idêntico ao cache dispensa o `clear()` + ~4600 `put`.
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
  Future<List<Louvor>> loadCachedLouvores() => _local.loadLouvores();

  @override
  Future<List<Louvor>> loadManifest() async {
    final cached = await _local.loadLouvores();
    final outcome = await syncManifest(cached: cached);
    return outcome.louvores;
  }

  @override
  Future<ManifestSyncOutcome> syncManifest({
    required List<Louvor> cached,
    String? knownChecksum,
  }) async {
    // `If-None-Match` só faz sentido com cache para preservar.
    final ifNoneMatch =
        cached.isNotEmpty && knownChecksum != null && knownChecksum.isNotEmpty
        ? knownChecksum
        : null;

    try {
      String? freshChecksum;

      if (ifNoneMatch != null) {
        final checksumResult = await _remote.fetchChecksumConditional(
          ifNoneMatch: ifNoneMatch,
        );

        if (checksumResult.isUnchanged) {
          debugPrint('[catalog] checksum inalterado — manifest não baixado');
          await _syncMetadata.markSyncedNow();
          return ManifestSyncOutcome(louvores: cached, cacheReplaced: false);
        }

        freshChecksum = checksumResult.checksum;
      }

      final fetched = await _remote.fetchManifestConditional(
        ifNoneMatch: ifNoneMatch,
      );
      final remoteLouvores = fetched.louvores;

      if (remoteLouvores == null) {
        debugPrint('[catalog] manifest 304 — cache preservado sem gravação');
        await _syncMetadata.markSyncedNow();
        return ManifestSyncOutcome(louvores: cached, cacheReplaced: false);
      }

      if (remoteLouvores.isEmpty) {
        debugPrint('[catalog] manifest remoto vazio — cache preservado');
        return ManifestSyncOutcome(
          louvores: cached.isEmpty ? remoteLouvores : cached,
          cacheReplaced: false,
        );
      }

      // O ETag do corpo tem prioridade sobre o `/checksum`: os dois endpoints
      // têm caches de browser independentes (`max-age=300`), então um checksum
      // fresco (Z) pode chegar com um corpo ainda em cache (Y). Salvar Z sobre o
      // corpo Y congelaria o catálogo em Y até o servidor mudar de novo.
      final checksum = fetched.etag ?? freshChecksum;

      if (fetched.etag == null) {
        debugPrint(
          '[catalog] resposta sem ETag — gate condicional desligado '
          'para este corpo',
        );
      }

      if (_isSameManifest(cached, remoteLouvores)) {
        debugPrint('[catalog] manifest idêntico ao cache — gravação evitada');
        await _syncMetadata.markSyncedNow();
        return ManifestSyncOutcome(
          louvores: cached,
          cacheReplaced: false,
          checksum: checksum,
        );
      }

      await cacheManifest(remoteLouvores);
      await _syncMetadata.markSyncedNow();
      await _notifyManifestReplaced(cached, remoteLouvores);
      return ManifestSyncOutcome(
        louvores: remoteLouvores,
        cacheReplaced: true,
        checksum: checksum,
      );
    } on Object catch (error) {
      debugPrint('[catalog] sync do manifest falhou: $error');
      if (cached.isNotEmpty) {
        return ManifestSyncOutcome(louvores: cached, cacheReplaced: false);
      }
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

  /// Compara cache e manifest remoto por ordem + campos de identidade.
  ///
  /// Cobre exatamente os campos que `LouvorCache` persiste (inclui `shortId`
  /// desde 2026-09) — regravar o Isar não mudaria mais nada. Barato o bastante
  /// (~4600 comparações) para valer a pena diante de um `clear()` + `putAll`,
  /// que na web é síncrono na thread da UI.
  static bool _isSameManifest(List<Louvor> cached, List<Louvor> remote) {
    if (cached.length != remote.length) return false;
    for (var i = 0; i < cached.length; i++) {
      final a = cached[i];
      final b = remote[i];
      if (a.pdfId != b.pdfId ||
          a.nome != b.nome ||
          a.numero != b.numero ||
          a.groupId != b.groupId ||
          a.categoria != b.categoria ||
          a.classificacao != b.classificacao ||
          a.pdf != b.pdf ||
          a.praiseId != b.praiseId ||
          a.materialId != b.materialId ||
          a.shortId != b.shortId) {
        return false;
      }
    }
    return true;
  }
}
