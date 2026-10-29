import 'package:flutter/foundation.dart';

import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../utils/catalog_tag_hierarchy.dart';
import 'louvor_group.dart';

/// Um tipo de material (`material_kind` do coldigom) oferecido como filtro.
///
/// [types]: os `MaterialKind` que esse kind tem no índice — é o que os chips
/// de Tipo da seção Materiais filtram (spec filtro-materiais §4.2).
class CatalogKindOption {
  const CatalogKindOption({
    required this.id,
    required this.name,
    this.types = const {},
  });

  final String id;
  final String name;
  final Set<MaterialKind> types;

  @override
  bool operator ==(Object other) =>
      other is CatalogKindOption &&
      other.id == id &&
      other.name == name &&
      setEquals(other.types, types);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAllUnordered(types));

  @override
  String toString() => 'CatalogKindOption($id, $name, $types)';
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
    this.tags = const [],
    this.materialKinds = const [],
  });

  /// Nada a oferecer — índice ainda vazio.
  static const empty = CatalogFilterOptions();

  final List<String> tonalities;
  final List<String> rhythms;
  final List<String> tags;
  final List<CatalogKindOption> materialKinds;

  factory CatalogFilterOptions.fromGroups(Iterable<LouvorGroup> groups) {
    final tonalities = <String>{};
    final rhythms = <String>{};
    final tags = <String>{};
    final kindNames = <String, String>{};
    final kindTypes = <String, Set<MaterialKind>>{};

    for (final group in groups) {
      final meta = group.coldigomMeta;
      if (meta != null) {
        _addValue(tonalities, meta.tonality);
        _addValue(rhythms, meta.rhythm);
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
            kindTypes,
            entry.louvor.materialKindId,
            entry.louvor.categoria,
            MaterialKind.pdf,
          );
        }
      }
      for (final material in group.extras) {
        _addKind(
          kindNames,
          kindTypes,
          material.materialKindId,
          material.categoria,
          material.kind,
        );
      }
    }

    final kinds =
        [
          for (final entry in kindNames.entries)
            CatalogKindOption(
              id: entry.key,
              name: entry.value,
              types: Set.unmodifiable(kindTypes[entry.key] ?? const {}),
            ),
        ]..sort((a, b) {
          final byName = _compareLabels(a.name, b.name);
          return byName != 0 ? byName : a.id.compareTo(b.id);
        });

    return CatalogFilterOptions(
      tonalities: _sorted(tonalities),
      rhythms: _sorted(rhythms),
      tags: _sorted(tags),
      materialKinds: List<CatalogKindOption>.unmodifiable(kinds),
    );
  }

  static void _addValue(Set<String> into, String raw) {
    final value = raw.trim();
    if (value.isNotEmpty) into.add(value);
  }

  static void _addKind(
    Map<String, String> names,
    Map<String, Set<MaterialKind>> types,
    String? id,
    String name,
    MaterialKind type,
  ) {
    if (id == null || id.isEmpty) return;
    final label = name.trim();
    names.putIfAbsent(id, () => label.isEmpty ? id : label);
    types.putIfAbsent(id, () => <MaterialKind>{}).add(type);
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
