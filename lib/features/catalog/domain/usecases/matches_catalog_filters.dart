import '../entities/catalog_filter_state.dart';
import '../entities/louvor_group.dart';
import '../entities/material_kind_taxonomy.dart';
import '../utils/catalog_tag_hierarchy.dart';
import '../utils/material_kind_selection.dart';

/// Predicado único dos filtros do catálogo (spec fim-fonte §2.2) — usado
/// pela /biblioteca, pela busca local e pelos «novos» da busca remota.
///
/// - Tom, ritmo: o valor do praise (`coldigomMeta`, aparado) está no
///   conjunto (OU). A seção da Coletânea é tag (`Coletânea · <seção>`), não
///   categoria (spec seções-coletânea §4.1).
/// - Tags: alguma tag do praise é uma selecionada ou filha dela
///   ([catalogTagMatches]: `PES` apanha `PES · 9.2026`). Subtag selecionada
///   junto com o pai refina o pai ([catalogTagsRefined]).
/// - Tipo de material: algum material do grupo tem um `materialKindId` da
///   seleção efetiva — pai expande nos filhos, pai + filho vale pelo filho
///   ([effectiveMaterialKindIds]).
/// - Entre filtros, E; filtro vazio não restringe. Um grupo sem
///   `coldigomMeta` só passa sem filtros de tom/ritmo/tags.
///
/// [effectiveKindIds] é o [effectiveMaterialKindIds] já resolvido — quem
/// varre muitos grupos na mesma passada (providers) computa uma vez e passa
/// aqui, em vez de refazer a conta a cada grupo. Sem ele, calcula na hora
/// (chamadas avulsas, como os testes).
bool matchesCatalogFilters(
  LouvorGroup group,
  CatalogFilterState filters, {
  MaterialKindTaxonomy? kindTaxonomy,
  Set<String>? effectiveKindIds,
}) {
  if (filters.isEmpty) return true;
  final meta = group.coldigomMeta;
  if (filters.tonalities.isNotEmpty &&
      (meta == null || !filters.tonalities.contains(meta.tonality.trim()))) {
    return false;
  }
  if (filters.rhythms.isNotEmpty &&
      (meta == null || !filters.rhythms.contains(meta.rhythm.trim()))) {
    return false;
  }
  if (filters.tags.isNotEmpty &&
      (meta == null ||
          !_hasSelectedTag(meta.tagNames, catalogTagsRefined(filters.tags)))) {
    return false;
  }
  if (filters.materialKindIds.isNotEmpty &&
      !_hasSelectedKind(
        group,
        effectiveKindIds ??
            effectiveMaterialKindIds(
              filters.materialKindIds,
              kindTaxonomy ?? MaterialKindTaxonomy.empty,
            ),
      )) {
    return false;
  }
  return true;
}

bool _hasSelectedTag(List<String> tagNames, Set<String> selected) {
  for (final raw in tagNames) {
    final tag = raw.trim();
    for (final wanted in selected) {
      if (catalogTagMatches(tag, wanted)) return true;
    }
  }
  return false;
}

/// Sem montar `group.materials` (lista nova a cada chamada): 2063 grupos por
/// tecla/filtro.
bool _hasSelectedKind(LouvorGroup group, Set<String> kinds) {
  for (final section in group.sections) {
    for (final entry in section.materials) {
      final kind = entry.louvor.materialKindId;
      if (kind != null && kinds.contains(kind)) return true;
    }
  }
  for (final material in group.extras) {
    final kind = material.materialKindId;
    if (kind != null && kinds.contains(kind)) return true;
  }
  return false;
}
