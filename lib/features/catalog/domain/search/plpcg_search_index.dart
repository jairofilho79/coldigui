import '../entities/catalog_query.dart';
import '../entities/louvor.dart';
import '../entities/louvor_group.dart';
import '../usecases/filter_by_material_and_arranjo.dart';
import '../usecases/group_louvores_by_material.dart';
import '../usecases/search_louvor_by_number_or_text.dart';
import '../utils/louvor_numero_normalizer.dart';

/// Índice de busca do acervo PLPCG, construído **uma vez por manifest** (A10).
///
/// Os campos `search*` de [Louvor] já vêm pré-computados da criação; o que
/// faltava era o número normalizado, que a busca antiga recalculava com regex
/// para cada um dos ~4600 louvores **a cada tecla**. [numeroNorm] guarda esse
/// valor alinhado por índice com [louvores] (`numeroNorm[i]` é o número
/// normalizado de `louvores[i]`).
final class PlpcgSearchIndex {
  const PlpcgSearchIndex._({required this.louvores, required this.numeroNorm});

  /// Índice vazio — o que a fonte PLPCG usa enquanto o manifest não chegou.
  static const empty = PlpcgSearchIndex._(
    louvores: <Louvor>[],
    numeroNorm: <String>[],
  );

  /// Normaliza o número de cada louvor uma vez só.
  factory PlpcgSearchIndex.build(List<Louvor> louvores) {
    if (louvores.isEmpty) return empty;
    return PlpcgSearchIndex._(
      louvores: List<Louvor>.unmodifiable(louvores),
      numeroNorm: List<String>.unmodifiable([
        for (final louvor in louvores)
          LouvorNumeroNormalizer.normalize(louvor.numero),
      ]),
    );
  }

  /// Louvores do manifest, na ordem original.
  final List<Louvor> louvores;

  /// Número normalizado de cada louvor, alinhado por índice com [louvores].
  final List<String> numeroNorm;
}

/// Pipeline local da Home — UC-01 → UC-02 → agrupamento, **síncrono**.
///
/// Substitui `runHomeSearchPipeline` sobre `compute` (no-op na web) por uma
/// varredura direta do índice: sem cópia do catálogo e sem normalizar número
/// por item.
List<LouvorGroup> runPlpcgSearchPipeline(
  PlpcgSearchIndex index,
  CatalogQuery query,
) {
  if (query.isEmpty || index.louvores.isEmpty) return const [];

  const search = SearchLouvorByNumberOrText();
  const filter = FilterByMaterialAndArranjo();
  const group = GroupLouvoresByMaterial();

  final searched = search.callIndexed(index, query.text);
  final filtered = filter(
    searched,
    selectedMaterials: query.filters.selectedMaterials,
    selectedArranjos: query.filters.selectedArranjos,
  );
  return group(filtered, sortByNumber: false);
}
