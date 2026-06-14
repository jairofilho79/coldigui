import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/repositories/manifest_checksum_reader.dart';

/// Persistência SharedPreferences do último checksum SHA-256 do manifest (UC-12 poll).
class ManifestChecksumStore implements ManifestChecksumReader {
  const ManifestChecksumStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> getLastKnownChecksum() async {
    final value = _prefs.getString(StorageKeys.manifestChecksum);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> saveChecksum(String checksum) async {
    await _prefs.setString(StorageKeys.manifestChecksum, checksum);
  }
}
