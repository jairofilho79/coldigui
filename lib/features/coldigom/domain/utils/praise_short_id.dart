/// `shortId` de praise no coldigom (spec fim-fonte §7.1): hex minúsculo de 3
/// a 8 dígitos, **sempre string** — nunca `int.parse` (`00f` ≠ `f`).
final _praiseShortIdPattern = RegExp(r'^[0-9a-f]{3,8}$');

/// [raw] normalizado (trim + minúsculas) quando é um `shortId` válido; senão
/// `null`. Tolerante como os DTOs (C.8): tipo errado não lança.
///
/// Usado pelos DTOs (dump e API), pelo índice (`groupByShortId`) e pelo
/// leitor do link `?p=` (plano 2).
String? normalizePraiseShortId(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim().toLowerCase();
  return _praiseShortIdPattern.hasMatch(value) ? value : null;
}
