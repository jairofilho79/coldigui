import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/constants/storage_keys.dart';

/// UC-10 — Migrar layout do store offline (Fase 3.6).
///
/// Move PDFs entre versões de diretório/schema; atualiza paths no índice Isar.
/// v1 nativa: no-op — apenas grava versão em prefs.
class MigrateOfflineStorage {
  const MigrateOfflineStorage(this._prefs);

  final SharedPreferences _prefs;

  Future<void> call() async {
    final stored = _prefs.getInt(StorageKeys.offlineStorageVersion) ?? 0;
    if (stored >= OfflineConfig.offlineStorageVersion) {
      return;
    }

    for (var version = stored;
        version < OfflineConfig.offlineStorageVersion;
        version++) {
      await _runMigration(version + 1);
    }

    await _prefs.setInt(
      StorageKeys.offlineStorageVersion,
      OfflineConfig.offlineStorageVersion,
    );
  }

  Future<void> _runMigration(int targetVersion) async {
    switch (targetVersion) {
      case 1:
        break;
      default:
        break;
    }
  }
}
