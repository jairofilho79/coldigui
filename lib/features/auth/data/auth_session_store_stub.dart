import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/auth_user.dart';

/// Sessão em memória + `SharedPreferences` (nativo / testes).
/// Web: [auth_session_store_web] — mesma API sobre `localStorage`.
///
/// Sem [prefs] fica só em memória — costura para testes que não querem
/// `SharedPreferences`; em produção o provider sempre passa a instância.
class AuthSessionStore {
  AuthSessionStore({this._prefs});

  static const String key = 'plpcg_auth_session';

  final SharedPreferences? _prefs;
  AuthUser? _cached;

  AuthUser? read() {
    if (_cached != null) return _cached;
    _cached = decode(_prefs?.getString(key));
    return _cached;
  }

  void write(AuthUser user) {
    _cached = user;
    // `setString` é assíncrono só no disco; a leitura seguinte já vê o valor.
    _prefs?.setString(key, encode(user));
  }

  void clear() {
    _cached = null;
    // Unawaited, como em `write`: o estado em memória já reflete a remoção.
    _prefs?.remove(key);
  }

  /// Serializa para JSON (usado pela implementação web).
  static String encode(AuthUser user) => jsonEncode(user.toJson());

  static AuthUser? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AuthUser.fromJson(Map<String, Object?>.from(decoded));
    } on Object {
      return null;
    }
  }
}
