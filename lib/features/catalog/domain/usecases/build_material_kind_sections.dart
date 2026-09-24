import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../entities/catalog_filter_options.dart';
import '../entities/material_kind_taxonomy.dart';

/// Ordem fixa dos chips de Tipo (spec filtro-materiais §4.2).
const List<MaterialKind> kMaterialTypeChipOrder = [
  MaterialKind.pdf,
  MaterialKind.chord,
  MaterialKind.audio,
  MaterialKind.youtube,
  MaterialKind.gesture,
];

/// Um chip da seção: kind sozinho ou família recolhida.
sealed class MaterialKindUnit {
  const MaterialKindUnit();
}

final class MaterialKindSingleUnit extends MaterialKindUnit {
  const MaterialKindSingleUnit(this.option);

  final CatalogKindOption option;
}

final class MaterialKindFamilyUnit extends MaterialKindUnit {
  const MaterialKindFamilyUnit({required this.parent, required this.children});

  final CatalogKindOption parent;
  final List<CatalogKindOption> children;
}

class MaterialKindSection {
  const MaterialKindSection({
    required this.classId,
    required this.label,
    required this.count,
    required this.units,
  });

  /// `null` = «Outros» (kind sem classe, ou taxonomia vazia).
  final String? classId;
  final String? label;

  /// Kinds visíveis na seção, pais e filhos.
  final int count;
  final List<MaterialKindUnit> units;
}

class MaterialKindSectionsView {
  const MaterialKindSectionsView({
    required this.sections,
    required this.hiddenCount,
    required this.typeCounts,
  });

  final List<MaterialKindSection> sections;

  /// Kinds escondidos pelos chips de Tipo marcados.
  final int hiddenCount;

  /// Kinds por tipo, na ordem de [kMaterialTypeChipOrder], só os presentes.
  final Map<MaterialKind, int> typeCounts;
}

typedef _Placed = ({String headId, MaterialKindUnit unit, int members});

/// Seções da lista de Materiais (spec filtro-materiais §5.1):
/// - um kind aparece se tem algum dos [types] (ou [types] vazio) ou está em
///   [selected] — um selecionado nunca some;
/// - filhos visíveis se juntam sob o pai; família com um membro visível só
///   vira chip simples;
/// - seções na ordem de `taxonomy.classes`, «Outros» por último; dentro,
///   pela ordem de grade e depois pelo nome.
MaterialKindSectionsView buildMaterialKindSections({
  required List<CatalogKindOption> options,
  required MaterialKindTaxonomy taxonomy,
  required Set<MaterialKind> types,
  required Set<String> selected,
}) {
  CatalogKindOption synthesized(String id) =>
      CatalogKindOption(id: id, name: taxonomy.kinds[id]?.name ?? id);

  final byId = <String, CatalogKindOption>{for (final o in options) o.id: o};
  for (final id in selected) {
    byId.putIfAbsent(id, () => synthesized(id));
  }

  bool visible(CatalogKindOption o) =>
      types.isEmpty || selected.contains(o.id) || o.types.any(types.contains);

  final shown = [
    for (final o in byId.values)
      if (visible(o)) o,
  ];
  final hiddenCount = byId.length - shown.length;

  final typeCounts = <MaterialKind, int>{};
  for (final type in kMaterialTypeChipOrder) {
    final n = options.where((o) => o.types.contains(type)).length;
    if (n > 0) typeCounts[type] = n;
  }

  final childrenByParent = <String, List<CatalogKindOption>>{};
  final roots = <CatalogKindOption>[];
  for (final o in shown) {
    final parentId = taxonomy.parentOf(o.id);
    if (parentId == null) {
      roots.add(o);
    } else {
      childrenByParent.putIfAbsent(parentId, () => []).add(o);
    }
  }

  int compare(CatalogKindOption a, CatalogKindOption b) {
    final byOrder = (taxonomy.kinds[a.id]?.order ?? 1 << 30).compareTo(
      taxonomy.kinds[b.id]?.order ?? 1 << 30,
    );
    return byOrder != 0 ? byOrder : _compareLabels(a.name, b.name);
  }

  final placed = <_Placed>[];
  for (final root in roots) {
    final kids = childrenByParent.remove(root.id);
    placed.add(
      kids == null
          ? (headId: root.id, unit: MaterialKindSingleUnit(root), members: 1)
          : (
              headId: root.id,
              unit: MaterialKindFamilyUnit(
                parent: root,
                children: kids..sort(compare),
              ),
              members: 1 + kids.length,
            ),
    );
  }
  // Pai fora da lista visível (escondido pelo tipo, ou sem material).
  for (final entry in childrenByParent.entries) {
    final kids = entry.value..sort(compare);
    if (kids.length == 1) {
      placed.add((
        headId: kids.single.id,
        unit: MaterialKindSingleUnit(kids.single),
        members: 1,
      ));
      continue;
    }
    placed.add((
      headId: entry.key,
      unit: MaterialKindFamilyUnit(
        parent: byId[entry.key] ?? synthesized(entry.key),
        children: kids,
      ),
      members: kids.length,
    ));
  }

  final known = {for (final c in taxonomy.classes) c.id};
  final bySection = <String?, List<_Placed>>{};
  for (final p in placed) {
    final classId = taxonomy.kinds[p.headId]?.classId;
    bySection
        .putIfAbsent(known.contains(classId) ? classId : null, () => [])
        .add(p);
  }

  MaterialKindSection section(String? classId, String? label) {
    final items = bySection[classId]!
      ..sort((a, b) => compare(_head(a.unit), _head(b.unit)));
    return MaterialKindSection(
      classId: classId,
      label: label,
      count: items.fold(0, (sum, p) => sum + p.members),
      units: [for (final p in items) p.unit],
    );
  }

  return MaterialKindSectionsView(
    sections: [
      for (final c in taxonomy.classes)
        if (bySection.containsKey(c.id)) section(c.id, c.label),
      if (bySection.containsKey(null)) section(null, null),
    ],
    hiddenCount: hiddenCount,
    typeCounts: typeCounts,
  );
}

CatalogKindOption _head(MaterialKindUnit unit) => switch (unit) {
  MaterialKindSingleUnit(:final option) => option,
  MaterialKindFamilyUnit(:final parent) => parent,
};

/// Sem acento nem caixa primeiro; desempate pelo texto cru (estável) — a
/// mesma ordem de `CatalogFilterOptions`.
int _compareLabels(String a, String b) {
  final byNormalized = LouvorSearchTokens.normalize(a)
      .compareTo(LouvorSearchTokens.normalize(b));
  return byNormalized != 0 ? byNormalized : a.compareTo(b);
}
