/// Prefixo do token de sessão emitido pelo Worker (`user_sessions`). É o que
/// o `AuthUnauthorizedInterceptor` usa para saber que um 401 é «sessão
/// revogada/vencida» e não uma rota pública.
const String kSessionTokenPrefix = 'sess_';

/// Usuário autenticado (sessão local + registro D1).
class AuthUser {
  const AuthUser({
    required this.googleSub,
    required this.sessionToken,
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

  /// Token de sessão do Worker (`sess_…`), Bearer de toda rota autenticada.
  /// Opaco: não tem `exp` legível — quem decide se ainda vale é o Worker.
  final String sessionToken;

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
    String? sessionToken,
  }) {
    return AuthUser(
      googleSub: googleSub ?? this.googleSub,
      email: email ?? this.email,
      name: name ?? this.name,
      pictureUrl: pictureUrl ?? this.pictureUrl,
      username: username ?? this.username,
      sessionToken: sessionToken ?? this.sessionToken,
    );
  }

  Map<String, Object?> toJson() => {
    'googleSub': googleSub,
    'email': email,
    'name': name,
    'pictureUrl': pictureUrl,
    'username': username,
    'sessionToken': sessionToken,
  };

  /// `null` para JSON sem `googleSub`/`sessionToken` — inclusive o formato
  /// antigo com `idToken`, que a migração (spec D12) trata por fora.
  static AuthUser? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final sub = json['googleSub'];
    final token = json['sessionToken'];
    if (sub is! String || sub.isEmpty || token is! String || token.isEmpty) {
      return null;
    }
    return AuthUser(
      googleSub: sub,
      email: json['email'] as String?,
      name: json['name'] as String?,
      pictureUrl: json['pictureUrl'] as String?,
      username: json['username'] as String?,
      sessionToken: token,
    );
  }
}
