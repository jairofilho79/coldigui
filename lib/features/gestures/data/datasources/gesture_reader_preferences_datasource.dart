import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/gesture_reader_font_size.dart';

/// Persistência do corpo da letra do leitor de gestos.
class GestureReaderPreferencesDatasource {
  const GestureReaderPreferencesDatasource(this._prefs);

  final SharedPreferences _prefs;

  /// Corpo salvo, ou [GestureReaderFontSize.initial]; fora da faixa é
  /// grampeado em vez de descartado.
  double getFontSize() {
    final stored = _prefs.getDouble(StorageKeys.gestureReaderFontSize);
    if (stored == null) return GestureReaderFontSize.initial;
    return GestureReaderFontSize.clamp(stored);
  }

  Future<void> saveFontSize(double size) =>
      _prefs.setDouble(StorageKeys.gestureReaderFontSize, size);
}
