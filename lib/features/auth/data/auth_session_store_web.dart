import 'package:web/web.dart' as web;

import '../domain/entities/auth_user.dart';
import 'auth_session_store_stub.dart' as stub;

/// Sessão em memória + `sessionStorage` (nunca `localStorage`).
class AuthSessionStore {
  static const _key = 'plpcg_auth_session';

  AuthUser? _cached;

  AuthUser? read() {
    if (_cached != null) return _cached;
    final raw = web.window.sessionStorage.getItem(_key);
    _cached = stub.AuthSessionStore.decode(raw);
    return _cached;
  }

  void write(AuthUser user) {
    _cached = user;
    web.window.sessionStorage.setItem(_key, stub.AuthSessionStore.encode(user));
  }

  void clear() {
    _cached = null;
    web.window.sessionStorage.removeItem(_key);
  }
}
