import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/usecases/cluster_member_order.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

List<String> _ids(List<LouvorGroup> groups) => [
  for (final g in groups) g.groupId,
];

void main() {
  test('membersOf: ordem fixa — número, nome, menos tags, sem número por '
      'último; inclui grupo de 1 membro', () {
    final index = catalogIndexOf([
      catalogGroup(
        praiseId: 'pes',
        number: '003',
        name: 'Clamo a ti',
        tags: const ['GLTM', 'PES', 'Coletânea · Clamor'],
        groupId: 'G1',
      ),
      catalogGroup(
        praiseId: 'avulso',
        name: 'Clamo a ti (avulso)',
        groupId: 'G1',
      ),
      catalogGroup(
        praiseId: 'col',
        number: '003',
        name: 'Clamo a ti',
        tags: const ['Coletânea · Clamor'],
        groupId: 'G1',
      ),
      catalogGroup(
        praiseId: 'so',
        number: '010',
        name: 'Sozinho',
        groupId: 'G2',
      ),
      catalogGroup(praiseId: 'livre', number: '011', name: 'Sem grupo'),
    ]);

    expect(_ids(index.membersOf('G1')), ['col', 'pes', 'avulso']);
    expect(_ids(index.membersOf('G2')), ['so']);
    expect(index.membersOf('desconhecido'), isEmpty);
    expect(ColdigomSearchIndex.empty.membersOf('G1'), isEmpty);
  });

  test('039: «39» e «039» empatam no número e o nome desempata', () {
    final index = catalogIndexOf([
      catalogGroup(
        praiseId: 'solo',
        number: '039',
        name: 'Jesus, Tu és o meu Deus (Solo)',
        groupId: 'G',
      ),
      catalogGroup(
        praiseId: 'sctb',
        number: '039',
        name: 'Jesus, Tu és o meu Deus (SCTB)',
        groupId: 'G',
      ),
      catalogGroup(
        praiseId: 'col',
        number: '39',
        name: 'Jesus, Tu és o meu Deus',
        groupId: 'G',
      ),
    ]);

    expect(_ids(index.membersOf('G')), ['col', 'sctb', 'solo']);
  });

  test('praiseGroupKeyOf lê o groupId da metadata', () {
    expect(
      praiseGroupKeyOf(catalogGroup(praiseId: 'a', name: 'A', groupId: 'G')),
      'G',
    );
    expect(praiseGroupKeyOf(catalogGroup(praiseId: 'b', name: 'B')), isNull);
  });

  test('compareClusterMembers: 034 antes de 307', () {
    final a = catalogGroup(praiseId: 'x', number: '307', name: 'Pelo vale');
    final b = catalogGroup(praiseId: 'y', number: '034', name: 'Pelo Vale');
    expect(_ids([a, b]..sort(compareClusterMembers)), ['y', 'x']);
  });
}
