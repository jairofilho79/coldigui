import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/lyrics_reader_font_size.dart';

/// Persistência do corpo do texto do leitor de letra.
class LyricsReaderPreferencesDatasource {
  const LyricsReaderPreferencesDatasource(this._prefs);

  final SharedPreferences _prefs;

  /// Corpo salvo, ou [LyricsReaderFontSize.initial]; fora da faixa é
  /// grampeado em vez de descartado.
  double getFontSize() {
    final stored = _prefs.getDouble(StorageKeys.lyricsReaderFontSize);
    if (stored == null) return LyricsReaderFontSize.initial;
    return LyricsReaderFontSize.clamp(stored);
  }

  Future<void> saveFontSize(double size) =>
      _prefs.setDouble(StorageKeys.lyricsReaderFontSize, size);
}
