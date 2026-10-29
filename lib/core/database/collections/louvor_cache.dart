import 'package:isar_plus/isar_plus.dart';

part 'louvor_cache.g.dart';

/// **Obsoleta.** Cache Isar do antigo manifesto PLPCG.
///
/// Coleção sem leitores; os dados são apagados no passo 5 do
/// `MigrateOfflineStorage`; sai do schema num follow-up depois de medir na
/// web (isar_plus SQLite/WASM + OPFS) que tirar uma coleção não impede a
/// abertura. Não alterar os campos: mudam o schema gerado.
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

  /// Agrupamento lógico do louvor.
  late String groupId;

  /// Id curto de share do manifesto; `null` quando ausente.
  String? shortId;

  /// Id do praise coldigom.
  String? praiseId;

  /// Id do material coldigom.
  String? materialId;
}
