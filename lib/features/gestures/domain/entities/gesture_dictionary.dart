/// Teto de saltos ao seguir `replacedBy` (contrato §3.4).
const kGestureAliasMaxHops = 5;

enum GestureStatus { active, deprecated }

/// Uma entrada do dicionário de gestos CIAs.
class GestureEntry {
  const GestureEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.exampleTriggers,
    required this.image,
    required this.gif,
    required this.status,
    required this.replacedBy,
    required this.updatedAt,
  });

  /// 12 hex, estável para sempre.
  final String id;
  final String name;
  final String description;
  final List<String> exampleTriggers;

  /// `r2_key` do PNG (`assets/cia/gestures/{id}.png`).
  final String image;

  /// `r2_key` do GIF animado, quando houver.
  final String? gif;

  final GestureStatus status;

  /// Id que substitui esta entrada quando [status] é `deprecated`.
  final String? replacedBy;

  final DateTime? updatedAt;
}

/// Dicionário global publicado por `GET /api/gestures/dictionary`.
class GestureDictionary {
  const GestureDictionary({
    required this.version,
    required this.generatedAt,
    required this.byId,
  });

  /// Dicionário sem entradas — o que a tela usa antes de o real chegar.
  static const empty = GestureDictionary(version: 0, generatedAt: null, byId: {});

  /// Inteiro monotônico; incrementa a cada alteração no coldigom.
  final int version;

  final DateTime? generatedAt;

  final Map<String, GestureEntry> byId;

  /// Entrada a renderizar para [id], seguindo a cadeia `replacedBy`.
  ///
  /// Para na primeira entrada `active`, em [kGestureAliasMaxHops] saltos, num
  /// `replacedBy` que não existe, ou num ciclo — nos três últimos casos devolve
  /// a última entrada visitada, porque mostrar uma figura velha é melhor que
  /// um placeholder. Só `null` quando [id] não está no dicionário.
  GestureEntry? resolve(String id) {
    final start = byId[id];
    if (start == null) return null;

    var current = start;
    final visited = <String>{current.id};
    for (var hop = 0; hop < kGestureAliasMaxHops; hop++) {
      if (current.status == GestureStatus.active) return current;
      final nextId = current.replacedBy;
      if (nextId == null || !visited.add(nextId)) return current;
      final next = byId[nextId];
      if (next == null) return current;
      current = next;
    }
    return current;
  }
}
