import 'package:flutter/foundation.dart';

import '../../../../core/database/storage_unavailable_exception.dart';
import '../../data/datasources/coldigom_catalog_local_datasource.dart';
import '../../data/datasources/coldigom_catalog_sync_metadata_store.dart';
import '../../data/datasources/coldigom_remote_datasource.dart';
import '../../data/mappers/coldigom_praise_cache_mapper.dart';

/// Desfecho de [SyncColdigomCatalog.run].
sealed class ColdigomCatalogSyncResult {
  const ColdigomCatalogSyncResult();
}

/// Dump novo gravado — quem hidrata os caches em memória precisa recarregar.
final class ColdigomCatalogSyncReplaced extends ColdigomCatalogSyncResult {
  const ColdigomCatalogSyncReplaced(this.count);

  final int count;
}

/// `304`: nada mudou.
final class ColdigomCatalogSyncNoop extends ColdigomCatalogSyncResult {
  const ColdigomCatalogSyncNoop();
}

/// Rede ou storage falharam; o catálogo local (se houver) fica como está.
final class ColdigomCatalogSyncFailed extends ColdigomCatalogSyncResult {
  const ColdigomCatalogSyncFailed(this.cause);

  final Object cause;
}

/// Sincroniza o catálogo Coldigom local por ETag (O3/O5).
///
/// Best-effort por contrato: nunca lança. `ColdigomCatalogSyncFailed.cause`
/// existe para a tela `/offline` explicar «não foi possível atualizar»; para
/// o boot e o foreground a falha é só um `debugPrint`. Sem Isar a escrita
/// lança [StorageUnavailableException] e o ETag **não** é gravado — senão o
/// próximo pedido receberia `304` para um banco vazio.
class SyncColdigomCatalog {
  SyncColdigomCatalog({
    required ColdigomRemoteDatasource remote,
    required ColdigomCatalogLocalDatasource local,
    required ColdigomCatalogSyncMetadataStore metadata,
    DateTime Function()? now,
  }) : _remote = remote, // ignore: prefer_initializing_formals
       _local = local, // ignore: prefer_initializing_formals
       _metadata = metadata, // ignore: prefer_initializing_formals
       _now = now ?? DateTime.now;

  final ColdigomRemoteDatasource _remote;
  final ColdigomCatalogLocalDatasource _local;
  final ColdigomCatalogSyncMetadataStore _metadata;
  final DateTime Function() _now;

  Future<ColdigomCatalogSyncResult> run() async {
    try {
      // Sem catálogo gravado o ETag guardado não vale: pedir sem
      // `If-None-Match` garante o corpo inteiro.
      final etag = _local.count() == 0 ? null : _metadata.readEtag();
      final result = await _remote.fetchCatalog(ifNoneMatch: etag);
      switch (result) {
        case ColdigomCatalogNotModified():
          await _metadata.markValidated(_now());
          return const ColdigomCatalogSyncNoop();
        case ColdigomCatalogFresh(:final catalog, etag: final freshEtag):
          final rows = [
            for (final praise in catalog.praises)
              ColdigomPraiseCacheMapper.fromCatalogPraise(
                praise,
                kindNames: catalog.kindNames,
              ),
          ];
          // Um `200` com corpo vazio é sinal de dump quebrado no servidor,
          // não «catálogo ficou vazio» — nunca apaga um catálogo bom local.
          if (rows.isEmpty) {
            return const ColdigomCatalogSyncFailed('dump vazio');
          }
          await _local.replaceAll(rows);
          await _metadata.markReplaced(
            etag: freshEtag,
            count: rows.length,
            at: _now(),
          );
          return ColdigomCatalogSyncReplaced(rows.length);
      }
    } on Object catch (error) {
      debugPrint('[coldigom] sync do catálogo falhou: $error');
      return ColdigomCatalogSyncFailed(error);
    }
  }
}
