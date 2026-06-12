import 'package:isar/isar.dart';

part 'louvor_cache.g.dart';

/// Cache local Isar do catálogo PLPCG (~4600+ louvores).
///
/// Espelha campos de [Louvor] para lookup offline e busca UC-01/03.
@Collection()
class LouvorCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String pdfId;

  late String nome;
  late String numero;
  late String categoria;
  late String classificacao;
  late String pdf;
}
