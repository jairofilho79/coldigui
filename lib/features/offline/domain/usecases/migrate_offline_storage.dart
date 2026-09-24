import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../data/datasources/offline_pdf_local_datasource.dart';
import '../ports/pdf_storage_port.dart';

/// Flag UC-09 do bulk PLPCG (legado; lida só pela v2, apagada pela v5).
const _offlineAvailableKey = 'OFFLINE_AVAILABLE';

/// Checksum do manifest (legado; apagado pela v4 e pela v5).
const _manifestChecksumKey = 'manifestChecksum';

/// Prefs sem leitor desde o fim da fonte PLPCG (spec 2026-09-23 §3.1/§6.4).
/// Literais de propósito: as constantes saíram de [StorageKeys].
const _deadPrefsV5 = [
  _manifestChecksumKey,
  'catalogLastSyncAt',
  'lastChecksumPollAt',
  'offlineSelectedCategories',
  'offlineBulkCategories',
  'offlineBulkCheckpoint',
  _offlineAvailableKey,
];

/// UC-10 — Migrar layout do store offline (Fase 3.6).
///
/// Move PDFs entre versões de diretório/schema; atualiza paths no índice Isar.
/// Os dados da coleção Isar `LouvorCache` não precisam de passo: o
/// `isar_plus` apaga uma coleção que saiu do schema ao abrir (medido
/// 2026-09-23, plano 3 do fim da fonte PLPCG, desvio 3).
class MigrateOfflineStorage {
  const MigrateOfflineStorage(this.prefs, this.local, this.store);

  final SharedPreferences prefs;
  final OfflinePdfLocalDatasource local;
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
        if (prefs.getString(_offlineAvailableKey) == 'TRUE') {
          await local.markAllPersistent();
        }
        break;
      case 3:
        await store.purgeLegacyStorage();
        if (kIsWeb) {
          await local.clearAll();
        }
        break;
      case 4:
        // shortId (set/2026): o checksum antigo casaria 304 e o cache nunca
        // ganharia o campo — força um download do corpo.
        await prefs.remove(_manifestChecksumKey);
        break;
      case 5:
        // Fim da fonte PLPCG: manifesto e secção PLPCG do /offline sem leitor.
        for (final key in _deadPrefsV5) {
          await prefs.remove(key);
        }
        break;
      default:
        break;
    }
  }
}
