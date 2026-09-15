import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/gesture_autoscroll_speed.dart';
import '../../domain/entities/gesture_reader_font_size.dart';
import '../../presentation/theme/gesture_reader_theme.dart';

/// Persistência das preferências do leitor de gestos: corpo da letra, tema,
/// leitura linear e velocidade do autoscroll. `running` do autoscroll **não**
/// persiste — cada abertura começa parada.
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

  /// Modo salvo, ou claro por padrão.
  GestureReaderMode getMode() =>
      GestureReaderMode.fromStorageString(
        _prefs.getString(StorageKeys.gestureReaderMode),
      ) ??
      GestureReaderMode.light;

  Future<void> saveMode(GestureReaderMode mode) =>
      _prefs.setString(StorageKeys.gestureReaderMode, mode.toStorageString());

  /// Leitura linear — ligada por padrão.
  bool getLinear() => _prefs.getBool(StorageKeys.gestureReaderLinear) ?? true;

  Future<void> saveLinear(bool linear) =>
      _prefs.setBool(StorageKeys.gestureReaderLinear, linear);

  /// Velocidade salva, ou [GestureAutoscrollSpeed.initial]; grampeada na faixa.
  int getAutoscrollSpeed() {
    final stored = _prefs.getInt(StorageKeys.gestureAutoscrollSpeed);
    if (stored == null) return GestureAutoscrollSpeed.initial;
    return GestureAutoscrollSpeed.clamp(stored);
  }

  Future<void> saveAutoscrollSpeed(int speed) =>
      _prefs.setInt(StorageKeys.gestureAutoscrollSpeed, speed);
}
