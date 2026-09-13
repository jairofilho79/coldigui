import 'dart:convert';

import 'oidc_redirect_request.dart';

/// Resultado da volta do Google (spec §3.2). `returnTo` já saneado (D8).
sealed class OidcCallbackResult {
  const OidcCallbackResult(this.returnTo);
  final String returnTo;
}

/// `id_token` com `nonce` e `csrf` conferidos — falta só o Worker validar.
final class OidcCallbackSuccess extends OidcCallbackResult {
  const OidcCallbackSuccess({required this.idToken, required String returnTo})
    : super(returnTo);
  final String idToken;
}

/// Usuário cancelou (ou Google recusou): `error=access_denied` etc.
final class OidcCallbackCancelled extends OidcCallbackResult {
  const OidcCallbackCancelled({required this.error, required String returnTo})
    : super(returnTo);
  final String error;
}

/// Callback que não pode ser aceito. `isContextMismatch` separa «o Google
/// respondeu num contexto que não iniciou o login» (aba restaurada, navegador
/// embutido do PWA iOS — spec D15) de adulteração/lixo.
final class OidcCallbackInvalid extends OidcCallbackResult {
  const OidcCallbackInvalid({required this.reason, required String returnTo})
    : super(returnTo);

  /// `state_missing | csrf_mismatch | nonce_mismatch | jwt_malformed | request_missing`
  final String reason;

  bool get isContextMismatch =>
      reason == 'request_missing' || reason == 'csrf_mismatch';
}

/// Lançada pelo `AuthNotifier` para o botão mostrar a UI de D15.
class OidcContextMismatchException implements Exception {
  const OidcContextMismatchException(this.reason);
  final String reason;

  @override
  String toString() => 'OidcContextMismatchException($reason)';
}

abstract final class OidcCallbackParser {
  // RFC 3986 pchar/query, sem `#` (fim do fragment) nem espaço — larga o
  // suficiente para querystrings reais (`,`, `+`, `:`, `()` etc.) mas sem
  // abrir mão de continuar sendo só um caminho do hash router (D8).
  static final RegExp _returnToPattern = RegExp(
    r"^/[A-Za-z0-9/_\-?=&%.+,'():@!*~;$]*$",
  );

  /// `fragment` é `location.hash` sem o `#`. Devolve `null` quando não é um
  /// callback do Google — rota normal do hash router (`/leitor?...`), vazio
  /// ou qualquer coisa sem `state`.
  ///
  /// A assinatura do JWT **não** é verificada aqui (papel do Worker, spec §5);
  /// só o `nonce` do payload é comparado com o do [request].
  static OidcCallbackResult? parse({
    required String fragment,
    required OidcRedirectRequest? request,
  }) {
    if (fragment.isEmpty || fragment.startsWith('/')) return null;
    final Map<String, String> params;
    try {
      params = Uri.splitQueryString(fragment);
    } on Object {
      return null;
    }
    final rawState = params['state'];
    if (rawState == null) return null;

    final state = OidcRedirectRequest.decodeState(rawState);
    if (state == null) {
      return const OidcCallbackInvalid(reason: 'state_missing', returnTo: '/');
    }
    final returnTo = sanitizeReturnTo(state['returnTo']);

    if (request == null) {
      return OidcCallbackInvalid(reason: 'request_missing', returnTo: returnTo);
    }
    if (state['csrf'] != request.csrf) {
      return OidcCallbackInvalid(reason: 'csrf_mismatch', returnTo: returnTo);
    }

    final error = params['error'];
    if (error != null && error.isNotEmpty) {
      return OidcCallbackCancelled(error: error, returnTo: returnTo);
    }

    final idToken = params['id_token'];
    final nonce = idToken == null ? null : _nonceOf(idToken);
    if (nonce == null) {
      return OidcCallbackInvalid(reason: 'jwt_malformed', returnTo: returnTo);
    }
    if (nonce != request.nonce) {
      return OidcCallbackInvalid(reason: 'nonce_mismatch', returnTo: returnTo);
    }
    return OidcCallbackSuccess(idToken: idToken!, returnTo: returnTo);
  }

  /// `nonce` do payload (2º segmento, base64url) ou `null` se malformado.
  static String? _nonceOf(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return null;
      final nonce = payload['nonce'];
      return nonce is String ? nonce : null;
    } on Object {
      return null;
    }
  }

  /// Caminho do hash router da própria app, ou `/` (spec D8).
  static String sanitizeReturnTo(String? raw) {
    if (raw == null || raw.startsWith('//')) return '/';
    return _returnToPattern.hasMatch(raw) ? raw : '/';
  }
}
