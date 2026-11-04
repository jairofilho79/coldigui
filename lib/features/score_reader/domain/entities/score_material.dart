/// Material "partitura editável" coldigom (`.mscz`/`.mxl`/`.musicxml`) — abre
/// em `/partitura`.
///
/// Mesma forma de `GestureMaterial`: [scoreId] vive no espaço do `pdfId`
/// (`encodePdfId(r2Key)`), para que carousel e playlist funcionem sem um
/// segundo espaço de ids. Ver `materialIdKindOf`.
class ScoreMaterial {
  const ScoreMaterial({
    required this.scoreId,
    required this.r2Key,
    required this.nome,
    required this.numero,
    required this.groupId,
    required this.categoria,
    required this.classificacao,
    this.author = '',
    this.materialKindId,
    this.notes,
  });

  /// `encodePdfId(r2Key)` — mesmo espaço do `pdfId`.
  final String scoreId;

  /// Chave do asset no R2 (`assets/praises/<praise>/<material>.mscz`).
  final String r2Key;

  final String nome;
  final String numero;
  final String groupId;

  /// Label do kind, ex.: `Grade`, `Vozes Masculinas`.
  final String categoria;

  final String classificacao;
  final String author;

  /// Id do `material_kind` Coldigom; `null` quando o dump não traz o kind.
  final String? materialKindId;

  /// Anotação rápida do arranjo/material (ex.: "I", "II").
  final String? notes;
}
