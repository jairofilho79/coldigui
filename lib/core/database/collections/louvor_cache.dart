import 'package:isar_plus/isar_plus.dart';

part 'louvor_cache.g.dart';

/// Cache local Isar do catálogo PLPCG (~4600+ louvores).
///
/// Espelha campos de [Louvor] para lookup offline e busca UC-01/03.
/// [groupId] vem do D1 remoto e preserva agrupamentos fuzzy do script Python.
@Collection()
class LouvorCache {
  int id = 0;

  @Index(unique: true)
  late String pdfId;

  late String nome;
  late String numero;
  late String categoria;
  late String classificacao;
  late String pdf;

  /// Agrupamento lógico do louvor — espelha [Louvor.groupId] do D1.
  late String groupId;

  /// Id curto de share — espelha [Louvor.shortId]; `null` quando ausente.
  String? shortId;

  /// Id do praise coldigom — espelha [Louvor.praiseId]; `null` antes do
  /// primeiro sync do manifest servido pelo coldigom.
  String? praiseId;

  /// Id do material coldigom — espelha [Louvor.materialId].
  String? materialId;
}
