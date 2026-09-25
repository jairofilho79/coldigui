import 'package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/usecases/cluster_catalog_list.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

LouvorGroup _g(String id, String number, {String? groupId}) => catalogGroup(
  praiseId: id,
  number: number,
  name: 'Louvor $id',
  groupId: groupId,
);

void main() {
  // a e b formam o grupo G; x e y são soltos.
  final a = _g('a', '001', groupId: 'G');
  final b = _g('b', '002', groupId: 'G');
  final x = _g('x', '003');
  final y = _g('y', '004');

  List<String> run(
    List<LouvorGroup> ordered,
    List<LouvorGroup> catalog, {
    List<LouvorGroup> extra = const [],
  }) {
    final index = catalogIndexOf(catalog);
    return [
      for (final entry in clusterCatalogList(
        ordered,
        membersOf: index.membersOf,
        extraMembers: extra,
      ))
        describeEntry(entry),
    ];
  }

  test('sem grupos: um chip por item, na ordem recebida', () {
    expect(run([y, x], [x, y]), ['y', 'x']);
  });

  test('o grupo entra na posição do membro mais bem colocado, e as '
      'aparições seguintes somem', () {
    expect(run([x, b, y, a], [a, b, x, y]), ['x', '[a b]', 'y']);
  });

  test('grupo sempre completo: quem não casou vem esmaecido', () {
    expect(run([b], [a, b]), ['[(a) b]']);
  });

  test('grupo sem nenhum membro que casou não aparece', () {
    expect(run([x], [a, b, x]), ['x']);
  });

  test('grupo que continua com 1 membro vira chip solto', () {
    final s = _g('s', '007', groupId: 'S');
    expect(run([s], [s]), ['s']);
  });

  test('membro só no índice + membro só remoto formam o amendoim', () {
    final r = _g('r', '002', groupId: 'G');
    expect(run([a, x, r], [a, x], extra: [r]), ['[a r]', 'x']);
  });

  test('membro presente no índice e no remoto não se repete', () {
    final bRemoto = _g('b', '002', groupId: 'G');
    expect(run([a, x, bRemoto], [a, b, x], extra: [bRemoto]), ['[a b]', 'x']);
  });

  test('a instância de ordered vence: o trecho da letra do remoto fica', () {
    final bRemoto = _g('b', '002', groupId: 'G').withColdigomMeta(
      const ColdigomPraiseMetadata(
        name: 'Louvor b',
        groupId: 'G',
        lyricsExcerpt: '…a ti pertence…',
      ),
    );
    final index = catalogIndexOf([a, b]);

    final cluster =
        clusterCatalogList(
              [a, bRemoto],
              membersOf: index.membersOf,
              extraMembers: [bRemoto],
            ).single
            as ClusterEntry;

    expect(cluster.praiseGroupId, 'G');
    expect(
      cluster.members.last.group.coldigomMeta?.lyricsExcerpt,
      '…a ti pertence…',
    );
  });
}
