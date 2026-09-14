import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../domain/entities/auth_user.dart';
import 'auth_session_store_stub.dart' as stub;

/// Sessão em memória + `localStorage` (spec D6): o token é opaco, revogável
/// e só o hash fica no Worker — por isso pode sobreviver a fechar a aba/PWA.
///
/// [prefs] é ignorado na web (assinatura comum com o stub).
class AuthSessionStore {
  // ignore: avoid_unused_constructor_parameters
  // `prefs` existe só para manter a mesma assinatura do stub (nativo); a web
  // persiste em `localStorage`, não em `SharedPreferences`.
  AuthSessionStore({SharedPreferences? prefs});

  static const String key = stub.AuthSessionStore.key;

  AuthUser? _cached;

  AuthUser? read() {
    if (_cached != null) return _cached;
    _cached = stub.AuthSessionStore.decode(
      web.window.localStorage.getItem(key),
    );
    return _cached;
  }

  void write(AuthUser user) {
    _cached = user;
    web.window.localStorage.setItem(key, stub.AuthSessionStore.encode(user));
  }

  void clear() {
    _cached = null;
    web.window.localStorage.removeItem(key);
  }

  /// Lê **e apaga** a sessão do formato antigo em `sessionStorage` (spec D12).
  /// Uma vez só: na carga seguinte já não existe.
  String? takeLegacySessionStorage() {
    final raw = web.window.sessionStorage.getItem(key);
    if (raw != null) web.window.sessionStorage.removeItem(key);
    return raw;
  }

  static String? legacyIdToken(String? raw) =>
      stub.AuthSessionStore.legacyIdToken(raw);
}
