import 'package:isar_plus/isar_plus.dart';

part 'coldigom_praise_cache.g.dart';

/// Cache local Isar do catálogo Coldigom (~1690 louvores) — spec offline
/// Coldigom §4.1 (O3).
///
/// Uma linha por praise; os materiais vão serializados em JSON na própria
/// linha ([materialsJson]) porque são lidos sempre em bloco (hidratação no
/// boot, enumeração do download) e nunca um a um. Substituição total por
/// sync numa transação, como [LouvorCache].
@Collection()
class ColdigomPraiseCache {
  int id = 0;

  /// `praise.id` do Worker — também o `groupId` das entidades Coldigom.
  @Index(unique: true)
  late String praiseId;

  /// Número como o Worker manda (`'001'`); pode ser vazio.
  late String number;

  late String name;
  late String author;
  late String rhythm;
  late String tonality;
  late String category;

  /// Nomes das tags (`tag_names`), sem ids.
  late List<String> tags;

  /// Letra; `''` quando não há (o dump omite o campo).
  late String lyrics;

  /// JSON array de `{id, kind, kindName, type, r2, size?, url?}` — ver
  /// `ColdigomPraiseCacheMapper`.
  late String materialsJson;

  /// Tokens normalizados (nome + número + tags + autor) separados por
  /// espaço — insumo do `ColdigomSearchIndex`, calculado uma vez no sync.
  late String searchTokens;
}
