import 'package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart';
import 'package:coldigui/features/catalog/domain/usecases/build_material_sheet_sections.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestItem {
  const _TestItem({required this.id, required this.name, this.kindId});

  final String id;
  final String name;
  final String? kindId;

  @override
  String toString() => name;
}

final _taxonomy = MaterialKindTaxonomy(
  classes: const [
    MaterialKindClass(id: 'regencia', label: 'Regência e geral'),
    MaterialKindClass(id: 'metais', label: 'Metais'),
    MaterialKindClass(id: 'cordas', label: 'Cordas'),
  ],
  kinds: const {
    'k-grade': MaterialKindTaxon(name: 'Grade', classId: 'regencia', order: 20),
    'k-partitura': MaterialKindTaxon(
      name: 'Partitura',
      classId: 'regencia',
      order: 10,
    ),
    'k-sax': MaterialKindTaxon(name: 'Saxofone', classId: 'metais', order: 30),
    'k-sax-alto': MaterialKindTaxon(
      name: 'Saxofone alto',
      parentId: 'k-sax',
      order: 50,
    ),
    'k-trompete': MaterialKindTaxon(
      name: 'Trompete',
      classId: 'metais',
      order: 40,
    ),
    'k-violino': MaterialKindTaxon(
      name: 'Violino I',
      classId: 'cordas',
      order: 10,
    ),
  },
);

void main() {
  group('buildMaterialSheetSections', () {
    test('retorna vazio se items for vazio ou taxonomia sem classes', () {
      final res1 = buildMaterialSheetSections<_TestItem>(
        items: const [],
        kindIdOf: (i) => i.kindId,
        taxonomy: _taxonomy,
      );
      expect(res1, isEmpty);

      final res2 = buildMaterialSheetSections<_TestItem>(
        items: const [
          _TestItem(id: '1', name: 'Grade', kindId: 'k-grade'),
        ],
        kindIdOf: (i) => i.kindId,
        taxonomy: MaterialKindTaxonomy.empty,
      );
      expect(res2, isEmpty);
    });

    test('retorna vazio se nenhum item tiver classe conhecida (fallback)', () {
      final items = const [
        _TestItem(id: '1', name: 'Desconhecido 1', kindId: 'k-inexistente'),
        _TestItem(id: '2', name: 'Sem kind', kindId: null),
      ];

      final res = buildMaterialSheetSections<_TestItem>(
        items: items,
        kindIdOf: (i) => i.kindId,
        taxonomy: _taxonomy,
      );
      expect(res, isEmpty);
    });

    test('agrupa pelas classes na ordem de taxonomy.classes e ordena por order/label', () {
      final items = const [
        _TestItem(id: '1', name: 'Violino I', kindId: 'k-violino'),
        _TestItem(id: '2', name: 'Grade', kindId: 'k-grade'),
        _TestItem(id: '3', name: 'Trompete', kindId: 'k-trompete'),
        _TestItem(id: '4', name: 'Partitura', kindId: 'k-partitura'),
        _TestItem(id: '5', name: 'Saxofone alto', kindId: 'k-sax-alto'),
      ];

      final res = buildMaterialSheetSections<_TestItem>(
        items: items,
        kindIdOf: (i) => i.kindId,
        taxonomy: _taxonomy,
        labelOf: (i) => i.name,
      );

      expect(res.length, 3);
      expect(res[0].classId, 'regencia');
      expect(res[0].label, 'Regência e geral');
      expect(res[0].items.map((i) => i.name), ['Partitura', 'Grade']);

      expect(res[1].classId, 'metais');
      expect(res[1].label, 'Metais');
      expect(res[1].items.map((i) => i.name), ['Trompete', 'Saxofone alto']);

      expect(res[2].classId, 'cordas');
      expect(res[2].label, 'Cordas');
      expect(res[2].items.map((i) => i.name), ['Violino I']);
    });

    test('favoritos sobem dentro de cada classe pela ordem do rank', () {
      final items = const [
        _TestItem(id: '1', name: 'Grade', kindId: 'k-grade'),
        _TestItem(id: '2', name: 'Partitura', kindId: 'k-partitura'),
        _TestItem(id: '3', name: 'Saxofone alto', kindId: 'k-sax-alto'),
        _TestItem(id: '4', name: 'Trompete', kindId: 'k-trompete'),
      ];

      // Rank dá preferência a Grade (ordem 20) sobre Partitura (ordem 10),
      // e Saxofone alto (ordem 50) sobre Trompete (ordem 40).
      final rank = {
        'k-grade': 0,
        'k-sax-alto': 1,
      };

      final res = buildMaterialSheetSections<_TestItem>(
        items: items,
        kindIdOf: (i) => i.kindId,
        taxonomy: _taxonomy,
        rank: rank,
        labelOf: (i) => i.name,
      );

      expect(res.length, 2);
      expect(res[0].classId, 'regencia');
      expect(res[0].items.map((i) => i.name), ['Grade', 'Partitura']);

      expect(res[1].classId, 'metais');
      expect(res[1].items.map((i) => i.name), ['Saxofone alto', 'Trompete']);
    });

    test('itens sem classe caem em Outros por último', () {
      final items = const [
        _TestItem(id: '1', name: 'Sem classe', kindId: null),
        _TestItem(id: '2', name: 'Trompete', kindId: 'k-trompete'),
      ];

      final res = buildMaterialSheetSections<_TestItem>(
        items: items,
        kindIdOf: (i) => i.kindId,
        taxonomy: _taxonomy,
        otherLabel: 'Outros',
        labelOf: (i) => i.name,
      );

      expect(res.length, 2);
      expect(res[0].classId, 'metais');
      expect(res[0].items.map((i) => i.name), ['Trompete']);

      expect(res[1].classId, isNull);
      expect(res[1].label, 'Outros');
      expect(res[1].items.map((i) => i.name), ['Sem classe']);
    });
  });
}
