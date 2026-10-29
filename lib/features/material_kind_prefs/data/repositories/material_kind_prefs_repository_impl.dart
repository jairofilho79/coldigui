import '../../domain/entities/material_kind_prefs.dart';
import '../../domain/repositories/material_kind_prefs_repository.dart';
import '../datasources/material_kind_prefs_local_datasource.dart';

class MaterialKindPrefsRepositoryImpl implements MaterialKindPrefsRepository {
  MaterialKindPrefsRepositoryImpl(this._local);

  final MaterialKindPrefsLocalDatasource _local;

  @override
  Future<MaterialKindPrefs?> read(String sub) async => _local.read(sub);

  @override
  Future<void> write(String sub, MaterialKindPrefs prefs) =>
      _local.write(sub, prefs);
}
