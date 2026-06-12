import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/offline_bulk_checkpoint.dart';

/// Persistência do checkpoint de resume do bulk UC-09.
class OfflineBulkCheckpointStore {
  const OfflineBulkCheckpointStore(this._prefs);

  final SharedPreferences _prefs;

  Future<OfflineBulkCheckpoint?> load() async {
    final raw = _prefs.getString(StorageKeys.offlineBulkCheckpoint);
    if (raw == null || raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return OfflineBulkCheckpoint.fromJson(json);
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> save(OfflineBulkCheckpoint checkpoint) async {
    await _prefs.setString(
      StorageKeys.offlineBulkCheckpoint,
      jsonEncode(checkpoint.toJson()),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(StorageKeys.offlineBulkCheckpoint);
  }
}
