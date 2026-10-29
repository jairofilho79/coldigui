/// `group_id` de praise no coldigom (spec louvores-agrupados §3.2): chave
/// **opaca** — hoje o id do praise âncora do grupo —, nunca tratada como id
/// de praise.
///
/// [raw] aparado quando é string não vazia; senão `null`. Tolerante como os
/// DTOs (C.8): tipo errado não lança.
String? normalizePraiseGroupId(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim();
  return value.isEmpty ? null : value;
}
