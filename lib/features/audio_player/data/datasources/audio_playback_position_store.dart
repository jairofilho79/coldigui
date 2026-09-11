import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

/// Última posição de reprodução gravada (spec B.4 C12).
///
/// Gravado a cada 5 s enquanto toca e no pause/stop; lido só no boot, dentro
/// de `AudioPlayerSessionNotifier.restoreQueue` — `playQueue` (tocar a partir
/// da lista/busca) sempre começa do zero.
class AudioPlaybackPositionStore {
  const AudioPlaybackPositionStore(this._prefs);

  final SharedPreferences _prefs;

  /// `null` quando não há posição gravada ou o JSON é inválido/incompleto —
  /// neste último caso a chave é limpa (não há como recuperar o valor).
  ({String trackId, Duration position})? read() {
    final raw = _prefs.getString(StorageKeys.audioLastPosition);
    if (raw == null || raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final trackId = json['trackId'] as String?;
      final positionMs = json['positionMs'] as int?;
      if (trackId == null || trackId.isEmpty || positionMs == null) {
        unawaited(clear());
        return null;
      }
      return (trackId: trackId, position: Duration(milliseconds: positionMs));
    } on Object {
      unawaited(clear());
      return null;
    }
  }

  Future<void> write(String trackId, Duration position) {
    return _prefs.setString(
      StorageKeys.audioLastPosition,
      jsonEncode({'trackId': trackId, 'positionMs': position.inMilliseconds}),
    );
  }

  Future<void> clear() => _prefs.remove(StorageKeys.audioLastPosition);
}
