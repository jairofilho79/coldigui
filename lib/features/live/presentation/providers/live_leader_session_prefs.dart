import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';

const kLiveLeaderSessionPrefsKey = 'live_leader_session';

/// «Eu estava ao vivo»: gravado em `startLive`, apagado em `endLive`/
/// `ended`. Se a app morrer a meio, o boot mostra «Retomar / Encerrar» (§7).
final class LiveLeaderSession {
  const LiveLeaderSession({
    required this.code,
    required this.playlistId,
    required this.playlistName,
  });
  final String code;
  final String playlistId;
  final String playlistName;

  Map<String, Object?> toJson() => {
    'code': code,
    'playlistId': playlistId,
    'playlistName': playlistName,
  };

  static LiveLeaderSession? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final code = raw['code'];
    final playlistId = raw['playlistId'];
    if (code is! String || playlistId is! String) return null;
    return LiveLeaderSession(
      code: code,
      playlistId: playlistId,
      playlistName: raw['playlistName'] as String? ?? '',
    );
  }
}

class LiveLeaderSessionPrefs {
  const LiveLeaderSessionPrefs({required this._prefs});
  final SharedPreferences _prefs;

  LiveLeaderSession? read() {
    final raw = _prefs.getString(kLiveLeaderSessionPrefsKey);
    if (raw == null) return null;
    try {
      return LiveLeaderSession.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> write(LiveLeaderSession session) => _prefs.setString(
    kLiveLeaderSessionPrefsKey,
    jsonEncode(session.toJson()),
  );

  Future<void> clear() => _prefs.remove(kLiveLeaderSessionPrefsKey);
}

final liveLeaderSessionPrefsProvider = Provider<LiveLeaderSessionPrefs>(
  (ref) => LiveLeaderSessionPrefs(prefs: ref.read(sharedPreferencesProvider)),
);

/// Sessão de gestor deixada pendente pelo último processo, ou `null`.
/// Invalidar depois de retomar/encerrar/descartar.
final pendingLeaderSessionProvider = Provider<LiveLeaderSession?>(
  (ref) => ref.read(liveLeaderSessionPrefsProvider).read(),
);
