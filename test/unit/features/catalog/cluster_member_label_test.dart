import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/usecases/cluster_member_label.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

LouvorGroup _m(String id, List<String> tags) =>
    catalogGroup(praiseId: id, name: 'Louvor $id', tags: tags);

List<String?> _labels(List<LouvorGroup> members) => [
  for (final m in members) clusterMemberLabel(m, members),
];

void main() {
  test('Clamo a ti: comum some; sem próprias, 1ª tag até o « · »', () {
    expect(
      _labels([
        _m('col', ['Coletânea · Clamor']),
        _m('pes', ['GLTM', 'PES', 'Coletânea · Clamor']),
      ]),
      ['Coletânea', 'GLTM · PES'],
    );
  });

  test('039: SCTB e Solo ficam PES; a da Coletânea fica Coletânea', () {
    expect(
      _labels([
        _m('39', ['Coletânea · Clamor']),
        _m('sctb', ['PES', 'Coletânea · Clamor']),
        _m('solo', ['PES', 'Coletânea · Clamor']),
      ]),
      ['Coletânea', 'PES', 'PES'],
    );
  });

  test('Pelo vale escuro: nada em comum, próprias em ordem alfabética', () {
    expect(
      _labels([
        _m('034', ['Avulsos', 'PES', 'Migrados']),
        _m('307', ['Coletânea · Consolo e Encorajamento']),
      ]),
      ['Avulsos · Migrados · PES', 'Coletânea · Consolo e Encorajamento'],
    );
  });

  test('a ordem de chegada das tags não muda a etiqueta', () {
    final ordemDoDump = [
      _m('034', ['Avulsos', 'Migrados', 'PES']),
      _m('307', ['Coletânea · Consolo e Encorajamento']),
    ];
    final ordemDaBusca = [
      _m('034', ['PES', 'Migrados', 'Avulsos']),
      _m('307', ['Coletânea · Consolo e Encorajamento']),
    ];
    expect(_labels(ordemDoDump), _labels(ordemDaBusca));
  });

  test('acento não bagunça a ordem (Éden entre Alfa e Ester)', () {
    expect(
      clusterMemberLabel(_m('a', ['Ester', 'Éden', 'Alfa']), [
        _m('a', ['Ester', 'Éden', 'Alfa']),
        _m('b', const []),
      ]),
      'Alfa · Éden · Ester',
    );
  });

  test('membro sem tag: sem etiqueta', () {
    expect(
      _labels([
        _m('a', const []),
        _m('b', ['PES']),
      ]),
      [null, 'PES'],
    );
  });

  test('todos com as mesmas tags: cada um mostra a 1ª até o « · »', () {
    expect(
      _labels([
        _m('a', ['Coletânea · Clamor']),
        _m('b', ['Coletânea · Clamor']),
      ]),
      ['Coletânea', 'Coletânea'],
    );
  });
}
