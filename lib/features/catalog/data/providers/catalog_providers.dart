import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/usecases/filter_by_material_and_arranjo.dart';
import '../../domain/usecases/filter_by_special_arrangement.dart';
import '../../domain/usecases/force_refresh_catalog.dart';
import '../../domain/usecases/group_louvores_by_material.dart';
import '../../domain/usecases/load_louvores_manifest.dart';
import '../../domain/usecases/poll_manifest_checksum.dart';
import '../../domain/usecases/search_louvor_by_number_or_text.dart';
import '../datasources/catalog_local_datasource.dart';
import '../datasources/catalog_remote_datasource.dart';
import '../datasources/catalog_sync_metadata_store.dart';
import '../datasources/manifest_checksum_store.dart';
import '../repositories/catalog_repository_impl.dart';

/// Cliente remoto do catálogo (manifest + checksum).
final catalogRemoteDatasourceProvider =
    Provider<CatalogRemoteDatasource>((ref) {
  return CatalogRemoteDatasource(ref.watch(dioProvider));
});

/// Persistência local Isar do catálogo.
final catalogLocalDatasourceProvider = Provider<CatalogLocalDatasource>((ref) {
  return CatalogLocalDatasource(ref.watch(isarProvider));
});

/// Metadados de sync do catálogo (timestamp último fetch remoto).
final catalogSyncMetadataStoreProvider =
    Provider<CatalogSyncMetadataStore>((ref) {
  return CatalogSyncMetadataStore(ref.watch(sharedPreferencesProvider));
});

/// Último checksum SHA-256 conhecido do manifest (UC-12 poll).
final manifestChecksumStoreProvider = Provider<ManifestChecksumStore>((ref) {
  return ManifestChecksumStore(ref.watch(sharedPreferencesProvider));
});

/// Repositório de catálogo — orquestra remote + local.
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepositoryImpl(
    remote: ref.watch(catalogRemoteDatasourceProvider),
    local: ref.watch(catalogLocalDatasourceProvider),
    syncMetadata: ref.watch(catalogSyncMetadataStoreProvider),
  );
});

/// Use case UC-12 — carregar manifest com fallback offline.
final loadLouvoresManifestProvider = Provider<LoadLouvoresManifest>((ref) {
  return LoadLouvoresManifest(ref.watch(catalogRepositoryProvider));
});

/// Use case UC-12 — refresh manual do catálogo (Fase 1.5).
final forceRefreshCatalogProvider = Provider<ForceRefreshCatalog>((ref) {
  return ForceRefreshCatalog(ref.watch(catalogRepositoryProvider));
});

/// Use case UC-12 — poll automático de checksum do manifest (Fase 5).
final pollManifestChecksumProvider = Provider<PollManifestChecksum>((ref) {
  return PollManifestChecksum(
    ref.watch(catalogRepositoryProvider),
    ref.watch(manifestChecksumStoreProvider),
  );
});

/// Use case UC-01 — busca por número ou texto na Home.
final searchLouvorByNumberOrTextProvider =
    Provider<SearchLouvorByNumberOrText>((ref) {
  return const SearchLouvorByNumberOrText();
});

/// Use case UC-02 — filtrar por material e arranjo.
final filterByMaterialAndArranjoProvider =
    Provider<FilterByMaterialAndArranjo>((ref) {
  return const FilterByMaterialAndArranjo();
});

/// Use case UC-03 — filtrar por arranjo especial (biblioteca).
final filterBySpecialArrangementProvider =
    Provider<FilterBySpecialArrangement>((ref) {
  return const FilterBySpecialArrangement();
});

/// Agrupa louvores filtrados por `groupId` (LOUVOR_GROUPING.md).
final groupLouvoresByMaterialProvider =
    Provider<GroupLouvoresByMaterial>((ref) {
  return const GroupLouvoresByMaterial();
});
