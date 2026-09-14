import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/auth_user.dart';

/// Sessão em memória + `SharedPreferences` (nativo / testes).
/// Web: [auth_session_store_web] — mesma API sobre `localStorage`.
///
/// Sem [prefs] fica só em memória — costura para testes que não querem
/// `SharedPreferences`; em produção o provider sempre passa a instância.
class AuthSessionStore {
  // Não dá para usar `this._prefs`: o parâmetro nomeado precisa se chamar
  // `prefs` (mesma assinatura pública da variante web).
  // ignore: prefer_initializing_formals
  AuthSessionStore({SharedPreferences? prefs}) : _prefs = prefs;

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
    _prefs?.remove(key);
  }

  /// Sessão do formato antigo (web, `sessionStorage`) — não existe no nativo.
  String? takeLegacySessionStorage() => null;

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

  /// `idToken` de um documento no formato anterior a esta spec (spec D12).
  static String? legacyIdToken(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final token = decoded['idToken'];
      return token is String && token.isNotEmpty ? token : null;
    } on Object {
      return null;
    }
  }
}
