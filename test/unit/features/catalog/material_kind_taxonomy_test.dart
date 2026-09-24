import 'package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json = <String, dynamic>{
    'kindClasses': [
      {'id': 'metais', 'label': 'Metais'},
      {'id': 'banda', 'label': 'Banda'},
    ],
    'kinds': [
      {'id': 'sax', 'name': 'Saxofone', 'class': 'metais', 'order': 30},
      {
        'id': 'sax-alto',
        'name': 'Saxofone alto',
        'class': 'metais',
        'parent': 'sax',
        'order': 50,
      },
      {
        'id': 'sax-tenor',
        'name': 'Saxofone tenor',
        'class': 'metais',
        'parent': 'sax',
        'order': 60,
      },
      {'id': 'novo', 'name': 'Novo'},
    ],
  };

  test('lê classes na ordem e kinds com classe, pai e ordem', () {
    final t = MaterialKindTaxonomy.fromJson(json);
    expect(t.classes, const [
      MaterialKindClass(id: 'metais', label: 'Metais'),
      MaterialKindClass(id: 'banda', label: 'Banda'),
    ]);
    expect(
      t.kinds['sax-alto'],
      const MaterialKindTaxon(
        name: 'Saxofone alto',
        classId: 'metais',
        parentId: 'sax',
        order: 50,
      ),
    );
    expect(t.kinds['novo'], const MaterialKindTaxon(name: 'Novo'));
    expect(t.childrenOf('sax'), ['sax-alto', 'sax-tenor']);
    expect(t.childrenOf('sax-alto'), isEmpty);
    expect(t.parentOf('sax-tenor'), 'sax');
    expect(t.parentOf('sax'), isNull);
    expect(t.isEmpty, isFalse);
  });

  test('toJson volta ao mesmo formato e relê igual', () {
    final t = MaterialKindTaxonomy.fromJson(json);
    final again = MaterialKindTaxonomy.fromJson(t.toJson());
    expect(again.classes, t.classes);
    expect(again.kinds, t.kinds);
  });

  test('tolerante: chaves ausentes, tipos errados e itens quebrados', () {
    final t = MaterialKindTaxonomy.fromJson({
      'kindClasses': 'x',
      'kinds': [
        42,
        {'id': 'a'},
        {'id': 'b', 'name': 'B', 'class': 7, 'parent': 'b', 'order': '3'},
      ],
    });
    expect(t.classes, isEmpty);
    // Sem nome o kind cai; pai de si mesmo e tipos errados viram nulos.
    expect(t.kinds, {'b': const MaterialKindTaxon(name: 'B')});
    expect(MaterialKindTaxonomy.fromJson(const {}).isEmpty, isTrue);
    expect(MaterialKindTaxonomy.empty.isEmpty, isTrue);
  });
}
