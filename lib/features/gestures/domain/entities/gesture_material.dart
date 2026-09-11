import '../../../catalog/domain/entities/louvor_data_source.dart';

/// Material "documento de gestos" coldigom — abre em `/gestos`.
///
/// Mesma forma de `ChordMaterial`: [gestureId] vive no espaço do `pdfId`
/// (`encodePdfId(r2Key)`), para que carousel e playlist funcionem sem um
/// segundo espaço de ids. Ver `materialIdKindOf`.
class GestureMaterial {
  const GestureMaterial({
    required this.gestureId,
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
  final String gestureId;

  /// Chave do asset no R2 (`assets/praises/<praise>/<material>.gestures`).
  final String r2Key;

  final String nome;
  final String numero;
  final String groupId;

  /// Label do kind, ex.: `Gestos`.
  final String categoria;

  final String classificacao;
  final String author;
  final LouvorDataSource source;
}
