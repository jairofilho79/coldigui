import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/contributions/data/datasources/contributions_remote_datasource.dart';
import 'package:coldigui/features/contributions/data/providers/contributions_providers.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_summary.dart';
import 'package:coldigui/features/contributions/presentation/providers/my_contributions_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/fake_auth_notifier.dart';

ContributionSummary _c(String id) => ContributionSummary(
  id: id,
  kind: ContributionKind.other,
  subkind: null,
  title: id,
  body: '',
  status: ContributionStatus.pendente,
  decisionNote: null,
  createdAt: DateTime.utc(2026, 9, 17),
  updatedAt: DateTime.utc(2026, 9, 17),
  links: const [],
  files: const [],
  fields: const {},
);

/// Datasource de mentira que devolve páginas fixas e registra os cursores
/// pedidos — verifica a paginação sem tocar em rede de verdade.
class _PagedDs extends ContributionsRemoteDatasource {
  _PagedDs() : super(Dio());
  final cursors = <String?>[];
  @override
  Future<ContributionsPage> fetchMine({
    required String sessionToken,
    String? cursor,
  }) async {
    cursors.add(cursor);
    return cursor == null
        ? ContributionsPage(items: [_c('a'), _c('b')], nextCursor: 'c2')
        : ContributionsPage(items: [_c('c')], nextCursor: null);
  }
}

void main() {
  test('carrega a primeira página e loadMore anexa com o cursor', () async {
    final ds = _PagedDs();
    final c = ProviderContainer(
      overrides: [
        contributionsRemoteDatasourceProvider.overrideWithValue(ds),
        authStateProvider.overrideWith(
          () => FakeAuthNotifier(
            const AuthUser(googleSub: 'u', sessionToken: 'sess_t'),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    final first = await c.read(myContributionsProvider.future);
    expect(first.items.map((e) => e.id), ['a', 'b']);
    expect(first.nextCursor, 'c2');
    await c.read(myContributionsProvider.notifier).loadMore();
    final after = c.read(myContributionsProvider).value!;
    expect(after.items.map((e) => e.id), ['a', 'b', 'c']);
    expect(after.nextCursor, isNull);
    expect(ds.cursors, [null, 'c2']);
    await c
        .read(myContributionsProvider.notifier)
        .loadMore(); // sem cursor: no-op
    expect(ds.cursors.length, 2);
  });

  test('deslogado devolve lista vazia sem chamar a rede', () async {
    final ds = _PagedDs();
    final c = ProviderContainer(
      overrides: [
        contributionsRemoteDatasourceProvider.overrideWithValue(ds),
        authStateProvider.overrideWith(() => FakeAuthNotifier(null)),
      ],
    );
    addTearDown(c.dispose);
    final s = await c.read(myContributionsProvider.future);
    expect(s.items, isEmpty);
    expect(ds.cursors, isEmpty);
  });
}
