import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

LouvorGroup _g(String id) =>
    LouvorGroup(groupId: id, numero: '001', nome: id, sections: const []);

void main() {
  final local = [_g('plpcg-1'), _g('cold-1')];

  test('a verificar: local na hora, sem novos', () {
    final state = HomeSearchState(
      query: 'x',
      localGroups: local,
      remote: const AsyncLoading(),
    );

    expect(state.freshness, SearchFreshness.checking);
    expect(state.groups.map((g) => g.groupId), ['plpcg-1', 'cold-1']);
    expect(state.newGroupIds, isEmpty);
    expect(state.remoteLoading, isTrue);
    expect(state.remoteFailed, isFalse);
  });

  test('remoto igual → atualizado; remoto com extra → atualizado com N novos no fim', () {
    final same = HomeSearchState(
      query: 'x',
      localGroups: local,
      remote: AsyncData(CatalogSearchPage(groups: [_g('cold-1')], page: 1)),
    );
    expect(same.freshness, SearchFreshness.updated);
    expect(same.newCount, 0);

    final withNew = HomeSearchState(
      query: 'x',
      localGroups: local,
      remote: AsyncData(
        CatalogSearchPage(groups: [_g('cold-1'), _g('cold-9')], page: 1),
      ),
      newGroups: [_g('cold-9')],
    );
    expect(withNew.freshness, SearchFreshness.updatedWithNew);
    expect(withNew.newCount, 1);
    expect(withNew.newGroupIds, {'cold-9'});
    expect(withNew.groups.last.groupId, 'cold-9');
  });

  test('erro → failed com a lista local intacta; offline → offline sem olhar o remoto', () {
    final failed = HomeSearchState(
      query: 'x',
      localGroups: local,
      remote: AsyncError(Exception('boom'), StackTrace.empty),
    );
    expect(failed.freshness, SearchFreshness.failed);
    expect(failed.remoteFailed, isTrue);
    expect(failed.groups, hasLength(2));

    final offline = HomeSearchState(
      query: 'x',
      localGroups: local,
      remote: const AsyncLoading(),
      offline: true,
    );
    expect(offline.freshness, SearchFreshness.offline);
    expect(offline.remoteLoading, isFalse);
    expect(offline.remoteFailed, isFalse);
  });

  test('query vazia', () {
    const state = HomeSearchState(
      query: '  ',
      localGroups: [],
      remote: AsyncData(CatalogSearchPage.empty),
    );
    expect(state.isEmptyQuery, isTrue);
    expect(state.freshness, SearchFreshness.updated);
  });
}
