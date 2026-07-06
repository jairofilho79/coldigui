import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../data/datasources/offline_available_store.dart';
import '../../data/datasources/offline_pdf_local_datasource.dart';
import '../ports/pdf_storage_port.dart';

/// UC-10 — Migrar layout do store offline (Fase 3.6).
///
/// Move PDFs entre versões de diretório/schema; atualiza paths no índice Isar.
class MigrateOfflineStorage {
  const MigrateOfflineStorage(
    this.prefs,
    this.local,
    this.offlineAvailableStore,
    this.store,
  );

  final SharedPreferences prefs;
  final OfflinePdfLocalDatasource local;
  final OfflineAvailableStore offlineAvailableStore;
  final PdfStoragePort store;

  Future<void> call() async {
    final stored = prefs.getInt(StorageKeys.offlineStorageVersion) ?? 0;
    if (stored >= OfflineConfig.offlineStorageVersion) {
      return;
    }

    for (
      var version = stored;
      version < OfflineConfig.offlineStorageVersion;
      version++
    ) {
      await _runMigration(version + 1);
    }

    await prefs.setInt(
      StorageKeys.offlineStorageVersion,
      OfflineConfig.offlineStorageVersion,
    );
  }

  Future<void> _runMigration(int targetVersion) async {
    switch (targetVersion) {
      case 1:
        break;
      case 2:
        if (offlineAvailableStore.isConfigured) {
          await local.markAllPersistent();
        }
        break;
      case 3:
        await store.purgeLegacyStorage();
        if (kIsWeb) {
          await local.clearAll();
        }
      default:
        break;
    }
  }
}
