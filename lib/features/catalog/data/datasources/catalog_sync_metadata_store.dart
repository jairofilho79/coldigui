import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

/// Metadados de sync do catálogo Isar — timestamp do último fetch remoto (UC-12).
class CatalogSyncMetadataStore {
  const CatalogSyncMetadataStore(this._prefs);

  static const staleThreshold = Duration(days: 7);

  final SharedPreferences _prefs;

  Future<void> markSyncedNow() async {
    await _prefs.setString(
      StorageKeys.catalogLastSyncAt,
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> getLastSyncAt() async {
    final value = _prefs.getString(StorageKeys.catalogLastSyncAt);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<bool> isStale() async {
    final lastSync = await getLastSyncAt();
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > staleThreshold;
  }
}
