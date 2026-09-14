import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../domain/usecases/sync_coldigom_catalog.dart';
import '../datasources/coldigom_catalog_local_datasource.dart';
import '../datasources/coldigom_catalog_sync_metadata_store.dart';
import 'coldigom_remote_providers.dart';

/// DI — catálogo Coldigom em Isar; `null` de Isar = modo degradado.
final coldigomCatalogLocalDatasourceProvider =
    Provider<ColdigomCatalogLocalDatasource>((ref) {
      final isar = ref.watch(optionalIsarProvider);
      if (isar == null) {
        return const ColdigomCatalogLocalDatasource.unavailable();
      }
      return ColdigomCatalogLocalDatasource(isar);
    });

/// DI — ETag/`syncedAt`/`count` do último sync.
final coldigomCatalogSyncMetadataStoreProvider =
    Provider<ColdigomCatalogSyncMetadataStore>((ref) {
      return ColdigomCatalogSyncMetadataStore(
        ref.watch(sharedPreferencesProvider),
      );
    });

/// DI — [SyncColdigomCatalog].
final syncColdigomCatalogProvider = Provider<SyncColdigomCatalog>((ref) {
  return SyncColdigomCatalog(
    remote: ref.watch(coldigomRemoteDatasourceProvider),
    local: ref.watch(coldigomCatalogLocalDatasourceProvider),
    metadata: ref.watch(coldigomCatalogSyncMetadataStoreProvider),
  );
});
