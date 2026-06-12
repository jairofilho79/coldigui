import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/offline/domain/usecases/migrate_offline_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('v0 para v1 grava versão sem alterar dados', () async {
    final prefs = await SharedPreferences.getInstance();
    final useCase = MigrateOfflineStorage(prefs);

    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
  });

  test('segunda execução é no-op', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      StorageKeys.offlineStorageVersion,
      OfflineConfig.offlineStorageVersion,
    );

    final useCase = MigrateOfflineStorage(prefs);
    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
  });
}
