import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../domain/repositories/material_kind_prefs_repository.dart';
import '../../domain/usecases/sync_material_kind_prefs.dart';
import '../datasources/material_kind_prefs_local_datasource.dart';
import '../datasources/material_kind_prefs_remote_datasource.dart';
import '../repositories/material_kind_prefs_repository_impl.dart';

/// Lê `sharedPreferencesProvider` — só resolva quando há usuário logado (em
/// testes sem override ele lança).
final materialKindPrefsLocalDatasourceProvider =
    Provider<MaterialKindPrefsLocalDatasource>((ref) {
      return MaterialKindPrefsLocalDatasource(
        ref.watch(sharedPreferencesProvider),
      );
    });

final materialKindPrefsRepositoryProvider =
    Provider<MaterialKindPrefsRepository>((ref) {
      return MaterialKindPrefsRepositoryImpl(
        ref.watch(materialKindPrefsLocalDatasourceProvider),
      );
    });

final materialKindPrefsRemoteDatasourceProvider =
    Provider<MaterialKindPrefsRemoteDatasource>((ref) {
      return MaterialKindPrefsRemoteDatasource(ref.watch(dioProvider));
    });

final syncMaterialKindPrefsProvider = Provider<SyncMaterialKindPrefs>((ref) {
  final remote = ref.watch(materialKindPrefsRemoteDatasourceProvider);
  return SyncMaterialKindPrefs(
    ref.watch(materialKindPrefsRepositoryProvider),
    remote.fetch,
    remote.put,
  );
});
