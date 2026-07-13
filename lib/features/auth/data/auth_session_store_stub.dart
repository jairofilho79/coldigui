import 'dart:convert';

import '../domain/entities/auth_user.dart';

/// Persistência em memória (nativo / testes). Web: [auth_session_store_web].
class AuthSessionStore {
  AuthUser? _cached;

  AuthUser? read() => _cached;

  void write(AuthUser user) {
    _cached = user;
  }

  void clear() {
    _cached = null;
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
