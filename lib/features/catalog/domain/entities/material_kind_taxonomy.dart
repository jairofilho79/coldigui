import 'package:flutter/foundation.dart';

/// Classe do filtro «Materiais» (Metais, Banda…) — `material_kind_classes`
/// do coldigom (spec filtro-materiais §2.1).
@immutable
class MaterialKindClass {
  const MaterialKindClass({required this.id, required this.label});

  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is MaterialKindClass && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);

  @override
  String toString() => 'MaterialKindClass($id, $label)';
}

/// Um kind na taxonomia: nome, classe, pai (família de um nível) e ordem de
/// grade dentro da classe. Tudo opcional menos o nome.
@immutable
class MaterialKindTaxon {
  const MaterialKindTaxon({
    required this.name,
    this.classId,
    this.parentId,
    this.order,
  });

  final String name;
  final String? classId;
  final String? parentId;
  final int? order;

  @override
  bool operator ==(Object other) =>
      other is MaterialKindTaxon &&
      other.name == name &&
      other.classId == classId &&
      other.parentId == parentId &&
      other.order == order;

  @override
  int get hashCode => Object.hash(name, classId, parentId, order);

  @override
  String toString() => 'MaterialKindTaxon($name, $classId, $parentId, $order)';
}

/// Classes e famílias dos material kinds, como o dump `GET /api/plpcg/catalog`
/// as manda (`kindClasses` + `class`/`parent`/`order` em `kinds`).
///
/// Vazia quando o coldigom ainda não tem a migração: a seção Materiais fica
/// plana, como antes.
class MaterialKindTaxonomy {
  MaterialKindTaxonomy({
    List<MaterialKindClass> classes = const [],
    Map<String, MaterialKindTaxon> kinds = const {},
  }) : classes = List.unmodifiable(classes),
       kinds = Map.unmodifiable(kinds),
       _children = _indexChildren(kinds);

  static final MaterialKindTaxonomy empty = MaterialKindTaxonomy();

  final List<MaterialKindClass> classes;
  final Map<String, MaterialKindTaxon> kinds;
  final Map<String, List<String>> _children;

  bool get isEmpty => classes.isEmpty && kinds.isEmpty;

  /// Filhos diretos de [id], na ordem em que vieram no dump.
  List<String> childrenOf(String id) => _children[id] ?? const [];

  String? parentOf(String id) => kinds[id]?.parentId;

  /// Mesma tolerância do resto do DTO: item quebrado cai, campo de tipo
  /// errado vira nulo, e um kind pai de si mesmo perde o pai.
  factory MaterialKindTaxonomy.fromJson(Map<String, dynamic> json) {
    final classes = <MaterialKindClass>[];
    final rawClasses = json['kindClasses'];
    for (final item in rawClasses is List<dynamic> ? rawClasses : const []) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      final label = item['label'];
      if (id is String && label is String) {
        classes.add(MaterialKindClass(id: id, label: label));
      }
    }
    final kinds = <String, MaterialKindTaxon>{};
    final rawKinds = json['kinds'];
    for (final item in rawKinds is List<dynamic> ? rawKinds : const []) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      final name = item['name'];
      if (id is! String || name is! String) continue;
      final classId = item['class'];
      final parentId = item['parent'];
      final order = item['order'];
      kinds[id] = MaterialKindTaxon(
        name: name,
        classId: classId is String ? classId : null,
        parentId: parentId is String && parentId != id ? parentId : null,
        order: order is int ? order : null,
      );
    }
    return MaterialKindTaxonomy(classes: classes, kinds: kinds);
  }

  Map<String, dynamic> toJson() => {
    'kindClasses': [
      for (final c in classes) {'id': c.id, 'label': c.label},
    ],
    'kinds': [
      for (final entry in kinds.entries)
        {
          'id': entry.key,
          'name': entry.value.name,
          if (entry.value.classId != null) 'class': entry.value.classId,
          if (entry.value.parentId != null) 'parent': entry.value.parentId,
          if (entry.value.order != null) 'order': entry.value.order,
        },
    ],
  };

  static Map<String, List<String>> _indexChildren(
    Map<String, MaterialKindTaxon> kinds,
  ) {
    final children = <String, List<String>>{};
    for (final entry in kinds.entries) {
      final parent = entry.value.parentId;
      if (parent != null) children.putIfAbsent(parent, () => []).add(entry.key);
    }
    return {
      for (final entry in children.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }
}
