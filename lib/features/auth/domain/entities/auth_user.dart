import 'dart:convert';

/// Usuário autenticado via Google (sessão local + registro D1).
class AuthUser {
  const AuthUser({
    required this.googleSub,
    required this.idToken,
    this.email,
    this.name,
    this.pictureUrl,
    this.username,
  });

  /// Claim `sub` do JWT Google — PK em D1 `users.google_sub`.
  final String googleSub;

  final String? email;
  final String? name;
  final String? pictureUrl;

  /// Handle público único (`users.username`). Null até o usuário cadastrar.
  final String? username;

  /// Google ID token (Bearer nas rotas `/api/auth/*`).
  final String idToken;

  bool get hasUsername => username != null && username!.isNotEmpty;

  /// Primeiro nome para a bottom bar (fallback: `Perfil`).
  String get displayFirstName {
    final full = name?.trim();
    if (full == null || full.isEmpty) return 'Perfil';
    return full.split(RegExp(r'\s+')).first;
  }

  AuthUser copyWith({
    String? googleSub,
    String? email,
    String? name,
    String? pictureUrl,
    String? username,
    String? idToken,
  }) {
    return AuthUser(
      googleSub: googleSub ?? this.googleSub,
      email: email ?? this.email,
      name: name ?? this.name,
      pictureUrl: pictureUrl ?? this.pictureUrl,
      username: username ?? this.username,
      idToken: idToken ?? this.idToken,
    );
  }

  Map<String, Object?> toJson() => {
    'googleSub': googleSub,
    'email': email,
    'name': name,
    'pictureUrl': pictureUrl,
    'username': username,
    'idToken': idToken,
  };

  static AuthUser? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final sub = json['googleSub'];
    final token = json['idToken'];
    if (sub is! String || sub.isEmpty || token is! String || token.isEmpty) {
      return null;
    }
    return AuthUser(
      googleSub: sub,
      email: json['email'] as String?,
      name: json['name'] as String?,
      pictureUrl: json['pictureUrl'] as String?,
      username: json['username'] as String?,
      idToken: token,
    );
  }
}

/// Expiração do `id_token` lida do claim `exp`.
///
/// O payload do JWT é decodificado (base64url) **sem validar a assinatura**:
/// quem valida é o Worker. Aqui só interessa saber quando pedir token novo.
extension AuthUserExpiry on AuthUser {
  /// Margem para considerar o token "expirando" e renovar preventivamente.
  static const Duration renewalWindow = Duration(minutes: 2);

  /// Instante (UTC) do claim `exp`, ou `null` se o token não for legível.
  DateTime? get expiresAt => _idTokenExpiry(idToken);

  /// `true` só quando há `exp` legível e ele já passou.
  bool get isExpired {
    final exp = expiresAt;
    return exp != null && !exp.isAfter(DateTime.now().toUtc());
  }

  /// `true` quando o token já expirou ou expira dentro de [renewalWindow].
  bool get expiresSoon {
    final exp = expiresAt;
    if (exp == null) return false;
    return exp.isBefore(DateTime.now().toUtc().add(renewalWindow));
  }
}

/// Token ilegível (formato inesperado, `exp` ausente) devolve `null` — sem
/// `exp` a sessão não pode ser tratada como expirada só por não dar para ler.
DateTime? _idTokenExpiry(String idToken) {
  final parts = idToken.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, Object?>) return null;
    final exp = decoded['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      (exp * 1000).round(),
      isUtc: true,
    );
  } on Object {
    return null;
  }
}
