import 'dart:convert';
import 'dart:math';

/// Chave em `sessionStorage` com o [OidcRedirectRequest] pendente (spec D6).
const String kOidcRequestStorageKey = 'plpcg_oidc_request';

/// Pedido de login por redirect OIDC (fluxo implícito, spec D1/D6/D7).
///
/// `nonce` vai no JWT devolvido pelo Google (anti-replay); `csrf` vai no
/// `state` e é conferido com o que ficou em `sessionStorage`. Os dois nascem
/// aqui, no clique, e morrem na captura do callback.
class OidcRedirectRequest {
  const OidcRedirectRequest({required this.nonce, required this.csrf});

  final String nonce;
  final String csrf;

  static final Uri _endpoint = Uri.parse(
    'https://accounts.google.com/o/oauth2/v2/auth',
  );

  /// 32 bytes aleatórios cada, base64url sem padding (43 chars).
  static OidcRedirectRequest generate([Random? random]) {
    final rng = random ?? Random.secure();
    return OidcRedirectRequest(nonce: _token(rng), csrf: _token(rng));
  }

  static String _token(Random rng) {
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return _b64(bytes);
  }

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// `state` = base64url(`{"csrf","returnTo"}`) sem padding (spec D7).
  static String encodeState({required String csrf, required String returnTo}) {
    return _b64(utf8.encode(jsonEncode({'csrf': csrf, 'returnTo': returnTo})));
  }

  /// Inverso de [encodeState]; `null` para qualquer coisa que não seja um
  /// objeto com `csrf` e `returnTo` strings.
  static Map<String, String>? decodeState(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(raw))),
      );
      if (decoded is! Map) return null;
      final csrf = decoded['csrf'];
      final returnTo = decoded['returnTo'];
      if (csrf is! String || returnTo is! String) return null;
      return {'csrf': csrf, 'returnTo': returnTo};
    } on Object {
      return null;
    }
  }

  /// URL de autorização do Google. `redirect_uri` é sempre `<origin>/` —
  /// só origens cadastradas no Console funcionam (spec D3).
  Uri authorizationUri({
    required String clientId,
    required Uri origin,
    required String returnTo,
  }) {
    final redirectUri = origin.replace(path: '/').toString();
    return _endpoint.replace(
      queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'id_token',
        'scope': 'openid email profile',
        'prompt': 'select_account',
        'nonce': nonce,
        'state': encodeState(csrf: csrf, returnTo: returnTo),
      },
    );
  }

  String toJson() => jsonEncode({'nonce': nonce, 'csrf': csrf});

  static OidcRedirectRequest? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final nonce = decoded['nonce'];
      final csrf = decoded['csrf'];
      if (nonce is! String || csrf is! String) return null;
      return OidcRedirectRequest(nonce: nonce, csrf: csrf);
    } on Object {
      return null;
    }
  }
}
