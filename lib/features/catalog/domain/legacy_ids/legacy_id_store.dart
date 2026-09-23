/// Resposta do crosswalk para os ids legados de uma rodada (spec 2026-09-23
/// §6.2).
final class LegacyIdResolution {
  LegacyIdResolution({
    required Set<String> queried,
    required Map<String, String> resolved,
  }) : queried = Set.unmodifiable(queried),
       resolved = Map.unmodifiable(resolved);

  /// Ids legados perguntados ao crosswalk nesta rodada.
  final Set<String> queried;

  /// Id legado → id coldigom (só os que o crosswalk conhece).
  final Map<String, String> resolved;

  /// `true` quando o crosswalk foi perguntado sobre [id] e não o conhece.
  bool isUnknown(String id) =>
      queried.contains(id) && !resolved.containsKey(id);

  /// O que fica no lugar de [id]: o id coldigom; `null` se é um legado
  /// desconhecido; o próprio [id] quando não foi perguntado (não é legado,
  /// ou apareceu depois da coleta — fica para a próxima rodada).
  String? rewrite(String id) {
    final mapped = resolved[id];
    if (mapped != null) return mapped;
    return isUnknown(id) ? null : id;
  }
}

/// Um sítio do aparelho que guarda ids de material (spec §6.2, facto M9).
///
/// Cada store decide o que fazer com um id desconhecido (a playlist mantém,
/// o índice offline apaga a linha, as prefs descartam) — a tabela do §6.2.
abstract interface class LegacyIdStore {
  /// Nome curto para o log.
  String get name;

  /// Ids legados guardados agora; vazio = nada a fazer aqui.
  Future<Set<String>> collectLegacyIds();

  /// Reescreve com [resolution]; devolve quantos registos mudaram.
  Future<int> rewrite(LegacyIdResolution resolution);
}
