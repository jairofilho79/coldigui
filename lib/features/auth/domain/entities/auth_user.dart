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
