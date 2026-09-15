import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

/// Metadados do sync do catálogo Coldigom em SharedPreferences: o ETag que
/// vai no `If-None-Match`, quando foi a última validação e quantos praises o
/// último dump trouxe (linha de estado do `/offline`).
///
/// Fora do Isar de propósito: sem Isar não há catálogo, e um ETag órfão
/// faria o próximo sync receber `304` para um banco vazio.
class ColdigomCatalogSyncMetadataStore {
  const ColdigomCatalogSyncMetadataStore(this._prefs);

  final SharedPreferences _prefs;

  String? readEtag() => _prefs.getString(StorageKeys.coldigomCatalogEtag);

  DateTime? readSyncedAt() {
    final raw = _prefs.getString(StorageKeys.coldigomCatalogSyncedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  int readCount() => _prefs.getInt(StorageKeys.coldigomCatalogCount) ?? 0;

  /// Dump novo gravado no Isar.
  Future<void> markReplaced({
    required String? etag,
    required int count,
    required DateTime at,
  }) async {
    if (etag == null) {
      await _prefs.remove(StorageKeys.coldigomCatalogEtag);
    } else {
      await _prefs.setString(StorageKeys.coldigomCatalogEtag, etag);
    }
    await _prefs.setInt(StorageKeys.coldigomCatalogCount, count);
    await markValidated(at);
  }

  /// `304`: o catálogo continua o do servidor — só a data muda.
  Future<void> markValidated(DateTime at) {
    return _prefs.setString(
      StorageKeys.coldigomCatalogSyncedAt,
      at.toUtc().toIso8601String(),
    );
  }
}
