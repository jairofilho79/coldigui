import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

/// Persistência da flag UC-09/UC-10 `OFFLINE_AVAILABLE` (legado PWA).
///
/// Valores: `TRUE` (bulk concluído → UC-10 na UI), `FALSE` (cache limpo → UC-09).
/// Ausente trata-se como não configurado (UC-09), salvo migração via [offlineModeProvider].
class OfflineAvailableStore {
  const OfflineAvailableStore(this._prefs);

  static const String enabledValue = 'TRUE';
  static const String disabledValue = 'FALSE';

  final SharedPreferences _prefs;

  bool get isConfigured =>
      _prefs.getString(StorageKeys.offlineAvailable) == enabledValue;

  /// Usuário limpou o cache — bloqueia re-inferência automática de bulk concluído.
  bool get isExplicitlyDisabled =>
      _prefs.getString(StorageKeys.offlineAvailable) == disabledValue;

  Future<void> markConfigured() =>
      _prefs.setString(StorageKeys.offlineAvailable, enabledValue);

  Future<void> clear() =>
      _prefs.setString(StorageKeys.offlineAvailable, disabledValue);
}
