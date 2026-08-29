import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../presentation/theme/chord_reader_theme.dart';

/// Persistência do claro/escuro do leitor de cifras.
class ChordReaderPreferencesDatasource {
  const ChordReaderPreferencesDatasource(this._prefs);

  final SharedPreferences _prefs;

  /// Modo salvo, ou claro por padrão.
  ChordReaderMode getMode() {
    return ChordReaderMode.fromStorageString(
          _prefs.getString(StorageKeys.chordReaderMode),
        ) ??
        ChordReaderMode.light;
  }

  Future<void> saveMode(ChordReaderMode mode) async {
    await _prefs.setString(StorageKeys.chordReaderMode, mode.toStorageString());
  }
}
