/// Espelha `workers/.../username_rules.ts` — handle 3–30: a-z 0-9 _.
abstract final class UsernameRules {
  static final RegExp pattern = RegExp(r'^[a-z0-9_]{3,30}$');

  static String normalize(String raw) => raw.trim().toLowerCase();

  /// Null se válido; senão chave de erro estável.
  static String? validate(String raw) {
    final normalized = normalize(raw);
    if (normalized.isEmpty) return 'username required';
    if (!pattern.hasMatch(normalized)) return 'invalid username';
    return null;
  }
}
