import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/chord_reader_font_size.dart';
import '../../presentation/theme/chord_reader_theme.dart';

/// Persistência das preferências do leitor de cifras (tema e corpo da letra).
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

  /// Corpo salvo, ou [ChordReaderFontSize.initial]; valor fora da faixa é
  /// grampeado em vez de descartado.
  double getFontSize() {
    final stored = _prefs.getDouble(StorageKeys.chordReaderFontSize);
    if (stored == null) return ChordReaderFontSize.initial;
    return ChordReaderFontSize.clamp(stored);
  }

  Future<void> saveFontSize(double size) async {
    await _prefs.setDouble(StorageKeys.chordReaderFontSize, size);
  }
}
