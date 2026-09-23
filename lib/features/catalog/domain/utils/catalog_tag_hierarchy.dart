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
