import '../entities/catalog_filter_state.dart';
import '../entities/louvor_group.dart';
import '../utils/catalog_tag_hierarchy.dart';

/// Predicado único dos filtros do catálogo (spec fim-fonte §2.2) — usado
/// pela /biblioteca, pela busca local e pelos «novos» da busca remota.
///
/// - Tom, ritmo, categoria: o valor do praise (`coldigomMeta`, aparado) está
///   no conjunto (OU).
/// - Tags: alguma tag do praise é uma selecionada ou filha dela
///   ([catalogTagMatches]: `PES` apanha `PES · 9.2026`).
/// - Tipo de material: algum material do grupo (PDF de secção ou extra) tem
///   o `materialKindId` no conjunto.
/// - Entre filtros, E; filtro vazio não restringe. Um grupo sem
///   `coldigomMeta` só passa sem filtros de tom/ritmo/categoria/tags.
bool matchesCatalogFilters(LouvorGroup group, CatalogFilterState filters) {
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
  if (filters.categories.isNotEmpty &&
      (meta == null || !filters.categories.contains(meta.category.trim()))) {
    return false;
  }
  if (filters.tags.isNotEmpty &&
      (meta == null || !_hasSelectedTag(meta.tagNames, filters.tags))) {
    return false;
  }
  if (filters.materialKindIds.isNotEmpty &&
      !_hasSelectedKind(group, filters.materialKindIds)) {
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
