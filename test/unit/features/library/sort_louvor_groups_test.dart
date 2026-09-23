import 'package:coldigui/features/library/domain/usecases/sort_louvor_groups.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  const sort = SortLouvorGroups();

  test('por número: numerados primeiro; sem número por nome, sem acento', () {
    final groups = [
      catalogGroup(praiseId: 'a', name: 'Zé do Brejo'),
      catalogGroup(praiseId: 'b', number: '002', name: 'Beta'),
      catalogGroup(praiseId: 'z', name: 'Águas vivas'),
      catalogGroup(praiseId: 'c', number: '001', name: 'Gama'),
      catalogGroup(praiseId: 'm', name: 'Brisa'),
    ];

    final result = sort(groups, sortBy: 'numero');

    // O desempate dos sem número é o nome («Águas» com o A), não o groupId.
    expect(result.map((g) => g.nome), [
      'Gama',
      'Beta',
      'Águas vivas',
      'Brisa',
      'Zé do Brejo',
    ]);
  });

  test('por nome: títulos acentuados ficam com a letra-base', () {
    final groups = [
      catalogGroup(praiseId: 'p1', name: 'Zebra'),
      catalogGroup(praiseId: 'p2', name: 'Éden'),
      catalogGroup(praiseId: 'p3', name: 'alfa'),
      catalogGroup(praiseId: 'p4', name: 'Ester'),
      catalogGroup(praiseId: 'p5', name: 'Ômega'),
    ];

    final result = sort(groups, sortBy: 'nome');

    expect(result.map((g) => g.nome), [
      'alfa',
      'Éden',
      'Ester',
      'Ômega',
      'Zebra',
    ]);
  });
}
