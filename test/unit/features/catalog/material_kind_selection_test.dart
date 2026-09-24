import 'package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart';
import 'package:coldigui/features/catalog/domain/utils/material_kind_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t = MaterialKindTaxonomy(
    kinds: const {
      'sax': MaterialKindTaxon(name: 'Saxofone'),
      'alto': MaterialKindTaxon(name: 'Saxofone alto', parentId: 'sax'),
      'tenor': MaterialKindTaxon(name: 'Saxofone tenor', parentId: 'sax'),
      'tuba': MaterialKindTaxon(name: 'Tuba'),
    },
  );

  group('toggleMaterialKindSelection', () {
    test('kind sem filhos liga e desliga', () {
      expect(toggleMaterialKindSelection({}, 'tuba', t), {'tuba'});
      expect(toggleMaterialKindSelection({'tuba'}, 'tuba', t), isEmpty);
    });

    test('marcar o pai tira os filhos marcados', () {
      expect(toggleMaterialKindSelection({'alto', 'tuba'}, 'sax', t), {
        'sax',
        'tuba',
      });
    });

    test('desmarcar o pai tira os filhos', () {
      expect(toggleMaterialKindSelection({'sax', 'tenor', 'tuba'}, 'sax', t), {
        'tuba',
      });
    });

    test('filho com o pai marcado liga junto (refina) e desliga sozinho', () {
      final refinado = toggleMaterialKindSelection({'sax'}, 'tenor', t);
      expect(refinado, {'sax', 'tenor'});
      expect(toggleMaterialKindSelection(refinado, 'tenor', t), {'sax'});
    });
  });

  group('effectiveMaterialKindIds', () {
    test('o pai expande para os filhos', () {
      expect(effectiveMaterialKindIds({'sax'}, t), {'sax', 'alto', 'tenor'});
    });

    test('pai + filho vale pelo filho', () {
      expect(effectiveMaterialKindIds({'sax', 'tenor'}, t), {'tenor'});
    });

    test('sem taxonomia é a própria seleção', () {
      expect(effectiveMaterialKindIds({'sax'}, MaterialKindTaxonomy.empty), {
        'sax',
      });
    });
  });

  test('materialKindFamilyState', () {
    expect(
      materialKindFamilyState('sax', ['alto', 'tenor'], {}),
      MaterialKindFamilyState.none,
    );
    expect(
      materialKindFamilyState('sax', ['alto', 'tenor'], {'sax'}),
      MaterialKindFamilyState.selected,
    );
    expect(
      materialKindFamilyState('sax', ['alto', 'tenor'], {'sax', 'alto'}),
      MaterialKindFamilyState.refined,
    );
    expect(
      materialKindFamilyState('sax', ['alto', 'tenor'], {'alto'}),
      MaterialKindFamilyState.refined,
    );
  });
}
