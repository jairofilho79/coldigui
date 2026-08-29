import '../../../catalog/domain/entities/louvor_data_source.dart';

/// Material de cifra ChordPro coldigom — abre em `/cifra`.
///
/// Espelha `YoutubeMaterial` na forma, mas com uma diferença deliberada:
/// [chordId] vive no mesmo espaço de ids do `pdfId` (Base64 URL-safe do path
/// relativo), para que carousel e playlist funcionem sem um segundo espaço de
/// ids. Ver `materialIdKindOf` em `lib/core/utils/material_id_kind.dart`.
class ChordMaterial {
  const ChordMaterial({
    required this.chordId,
    required this.r2Key,
    required this.nome,
    required this.numero,
    required this.groupId,
    required this.categoria,
    required this.classificacao,
    this.author = '',
    this.source = LouvorDataSource.coldigom,
  });

  /// `encodePdfId(r2Key)` — mesmo espaço do `pdfId`.
  final String chordId;

  /// Chave do asset no R2 (`assets/praises/<praise>/<material>.chord`).
  final String r2Key;

  final String nome;
  final String numero;
  final String groupId;

  /// Label do kind: `Cifra`, `Cifra I`, `Cifra II`.
  final String categoria;

  final String classificacao;
  final String author;
  final LouvorDataSource source;
}
