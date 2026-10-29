import '../entities/material_kind_taxonomy.dart';

/// Estado do chip de família (spec filtro-materiais §5.2).
enum MaterialKindFamilyState {
  /// Nada da família marcado.
  none,

  /// Só o pai marcado: vale a família inteira.
  selected,

  /// Algum filho marcado, com ou sem o pai: vale só o que está marcado.
  refined,
}

/// Toque num chip de kind com a regra das subtags (`d8dd304d`): marcar o pai
/// vale pela família (tira os filhos), desmarcar o pai tira os filhos, e um
/// filho liga e desliga sozinho — com o pai marcado, ele refina o pai.
Set<String> toggleMaterialKindSelection(
  Set<String> selected,
  String id,
  MaterialKindTaxonomy taxonomy,
) {
  final children = taxonomy.childrenOf(id);
  if (children.isEmpty) {
    return selected.contains(id)
        ? ({...selected}..remove(id))
        : {...selected, id};
  }
  final withoutChildren = {
    for (final s in selected)
      if (!children.contains(s)) s,
  };
  return selected.contains(id)
      ? (withoutChildren..remove(id))
      : (withoutChildren..add(id));
}

/// Os ids que o casamento usa: primeiro refina (pai com filho marcado sai,
/// como `catalogTagsRefined`), depois expande cada pai que sobrou nos filhos
/// (como `catalogTagMatches`).
Set<String> effectiveMaterialKindIds(
  Set<String> selected,
  MaterialKindTaxonomy taxonomy,
) {
  final refined = {
    for (final id in selected)
      if (!taxonomy.childrenOf(id).any(selected.contains)) id,
  };
  return {
    for (final id in refined) ...[id, ...taxonomy.childrenOf(id)],
  };
}

MaterialKindFamilyState materialKindFamilyState(
  String parentId,
  Iterable<String> childIds,
  Set<String> selected,
) {
  if (childIds.any(selected.contains)) return MaterialKindFamilyState.refined;
  if (selected.contains(parentId)) return MaterialKindFamilyState.selected;
  return MaterialKindFamilyState.none;
}
