import '../../../../core/utils/louvor_search_tokens.dart';
import '../utils/catalog_tag_hierarchy.dart';
import 'louvor_group.dart';

/// Um tipo de material (`material_kind` do coldigom) oferecido como filtro.
class CatalogKindOption {
  const CatalogKindOption({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is CatalogKindOption && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'CatalogKindOption($id, $name)';
}

/// Os chips de cada filtro do catálogo — derivados do índice local, nunca
/// de `/api/praises/filters` nem `/api/materials/kinds` (spec fim-fonte §2.2).
///
/// Só aparecem valores com ≥1 praise. Tags incluem os ancestrais (`PES`
/// para `PES · 9.2026`), porque selecionar o pai apanha os filhos.
class CatalogFilterOptions {
  const CatalogFilterOptions({
    this.tonalities = const [],
    this.rhythms = const [],
    this.categories = const [],
    this.tags = const [],
    this.materialKinds = const [],
  });

  /// Nada a oferecer — índice ainda vazio.
  static const empty = CatalogFilterOptions();

  final List<String> tonalities;
  final List<String> rhythms;
  final List<String> categories;
  final List<String> tags;
  final List<CatalogKindOption> materialKinds;

  factory CatalogFilterOptions.fromGroups(Iterable<LouvorGroup> groups) {
    final tonalities = <String>{};
    final rhythms = <String>{};
    final categories = <String>{};
    final tags = <String>{};
    final kindNames = <String, String>{};

    for (final group in groups) {
      final meta = group.coldigomMeta;
      if (meta != null) {
        _addValue(tonalities, meta.tonality);
        _addValue(rhythms, meta.rhythm);
        _addValue(categories, meta.category);
        for (final raw in meta.tagNames) {
          final tag = raw.trim();
          if (tag.isEmpty) continue;
          tags.addAll(catalogTagWithAncestors(tag));
        }
      }
      for (final section in group.sections) {
        for (final entry in section.materials) {
          _addKind(
            kindNames,
            entry.louvor.materialKindId,
            entry.louvor.categoria,
          );
        }
      }
      for (final material in group.extras) {
        _addKind(kindNames, material.materialKindId, material.categoria);
      }
    }

    final kinds =
        [
          for (final entry in kindNames.entries)
            CatalogKindOption(id: entry.key, name: entry.value),
        ]..sort((a, b) {
          final byName = _compareLabels(a.name, b.name);
          return byName != 0 ? byName : a.id.compareTo(b.id);
        });

    return CatalogFilterOptions(
      tonalities: _sorted(tonalities),
      rhythms: _sorted(rhythms),
      categories: _sorted(categories),
      tags: _sorted(tags),
      materialKinds: List<CatalogKindOption>.unmodifiable(kinds),
    );
  }

  static void _addValue(Set<String> into, String raw) {
    final value = raw.trim();
    if (value.isNotEmpty) into.add(value);
  }

  static void _addKind(Map<String, String> into, String? id, String name) {
    if (id == null || id.isEmpty) return;
    final label = name.trim();
    into.putIfAbsent(id, () => label.isEmpty ? id : label);
  }

  static List<String> _sorted(Set<String> values) =>
      List<String>.unmodifiable(values.toList()..sort(_compareLabels));

  /// Sem acento nem caixa primeiro; desempate pelo texto cru (estável).
  static int _compareLabels(String a, String b) {
    final byNormalized = LouvorSearchTokens.normalize(a)
        .compareTo(LouvorSearchTokens.normalize(b));
    return byNormalized != 0 ? byNormalized : a.compareTo(b);
  }
}
