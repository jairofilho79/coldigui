/// Separador de hierarquia nas tags do coldigom (`PES · 9.2026`).
const catalogTagHierarchySeparator = ' · ';

/// `true` quando [tag] é [selected] ou um descendente dele — «o pai inclui
/// os filhos» (spec fim-fonte §2.2). `PESCA` não é filho de `PES`: o prefixo
/// tem de acabar no separador.
bool catalogTagMatches(String tag, String selected) =>
    tag == selected || tag.startsWith('$selected$catalogTagHierarchySeparator');

/// [tag] e cada ancestral, do mais geral à própria tag:
/// `A · B · C` → `A`, `A · B`, `A · B · C`.
Iterable<String> catalogTagWithAncestors(String tag) sync* {
  final parts = tag.split(catalogTagHierarchySeparator);
  for (var i = 1; i <= parts.length; i++) {
    yield parts.sublist(0, i).join(catalogTagHierarchySeparator);
  }
}

/// Pai imediato de [tag] (`A · B · C` → `A · B`); `null` numa raiz.
String? catalogTagParent(String tag) {
  final cut = tag.lastIndexOf(catalogTagHierarchySeparator);
  return cut < 0 ? null : tag.substring(0, cut);
}

/// Último nível de [tag] (`A · B · C` → `C`), o rótulo do chip de subtag.
String catalogTagLeaf(String tag) {
  final cut = tag.lastIndexOf(catalogTagHierarchySeparator);
  return cut < 0
      ? tag
      : tag.substring(cut + catalogTagHierarchySeparator.length);
}

/// A seleção que vale para o filtro: tag com algum descendente também
/// selecionado sai — a subtag refina o pai (`PES` + `PES · 9.2026` filtra
/// só `PES · 9.2026`). Sem descendente selecionado, o pai inclui os filhos.
Set<String> catalogTagsRefined(Set<String> selected) => {
  for (final tag in selected)
    if (!selected.any((other) => other != tag && catalogTagMatches(other, tag)))
      tag,
};
