import 'dart:async';

import 'package:coldigui/features/catalog/data/providers/catalog_source_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/ports/catalog_source.dart';
import 'package:coldigui/features/catalog/domain/ports/search_cancellation.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_remote_search_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fonte de catálogo que registra cada busca (query + cancelamento) e responde
/// pelo roteiro do teste.
class _RecordingCatalogSource implements CatalogSource {
  _RecordingCatalogSource(this._respond);

  /// Responde sempre com uma página vazia da página pedida.
  factory _RecordingCatalogSource.ok() {
    return _RecordingCatalogSource(
      (query, _) async => CatalogSearchPage(groups: const [], page: query.page),
    );
  }

  final Future<CatalogSearchPage> Function(
    CatalogQuery query,
    SearchCancellation? cancellation,
  )
  _respond;

  final queries = <CatalogQuery>[];
  final cancellations = <SearchCancellation?>[];

  int get searchCalls => queries.length;

  @override
  List<LouvorGroup> searchLocal(CatalogQuery query) => const [];

  @override
  Future<CatalogSearchPage> search(
    CatalogQuery query, {
    SearchCancellation? cancellation,
  }) {
    queries.add(query);
    cancellations.add(cancellation);
    return _respond(query, cancellation);
  }

  @override
  Future<LouvorGroup?> groupById(String groupId) async => null;

  @override
  Future<CatalogMaterial?> materialById(String materialId) async => null;

  @override
  Future<LouvorGroup?> groupForMaterial(String materialId) async => null;
}

ProviderContainer _createContainer(CatalogSource source) {
  final container = ProviderContainer(
    overrides: [catalogSourceProvider.overrideWithValue(source)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('HomeRemoteSearchKey', () {
    test('igualdade e hashCode por (query, página)', () {
      const a = HomeRemoteSearchKey(query: 'agua', page: 2);
      const b = HomeRemoteSearchKey(query: 'agua', page: 2);
      const outraPagina = HomeRemoteSearchKey(query: 'agua', page: 3);
      const outraQuery = HomeRemoteSearchKey(query: 'fogo', page: 2);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(outraPagina));
      expect(a, isNot(outraQuery));
    });
  });

  test('query vazia devolve página vazia sem tocar a fonte remota', () async {
    final source = _RecordingCatalogSource.ok();
    final container = _createContainer(source);

    final page = await container.read(
      homeRemoteSearchProvider(
        const HomeRemoteSearchKey(query: '   ', page: 1),
      ).future,
    );

    expect(page.groups, isEmpty);
    expect(page.page, 1);
    expect(source.searchCalls, 0);
  });

  test('cada instância recebe a própria SearchCancellation', () async {
    final source = _RecordingCatalogSource.ok();
    final container = _createContainer(source);

    await container.read(
      homeRemoteSearchProvider(
        const HomeRemoteSearchKey(query: 'agua', page: 1),
      ).future,
    );
    await container.read(
      homeRemoteSearchProvider(
        const HomeRemoteSearchKey(query: 'agua', page: 2),
      ).future,
    );

    expect(source.cancellations, hasLength(2));
    expect(source.cancellations[0], isNotNull);
    expect(source.cancellations[1], isNotNull);
    expect(
      identical(source.cancellations[0], source.cancellations[1]),
      isFalse,
    );
  });

  test('descartar o provider cancela a SearchCancellation em voo', () async {
    final pending = Completer<CatalogSearchPage>();
    final source = _RecordingCatalogSource((_, _) => pending.future);
    final container = _createContainer(source);

    final sub = container.listen(
      homeRemoteSearchProvider(
        const HomeRemoteSearchKey(query: 'agua', page: 1),
      ),
      (_, _) {},
    );
    await pumpEventQueue();

    final cancellation = source.cancellations.single!;
    expect(cancellation.isCancelled, isFalse);

    sub.close();
    await pumpEventQueue();

    expect(cancellation.isCancelled, isTrue);

    pending.complete(const CatalogSearchPage(groups: [], page: 1));
    await pumpEventQueue();
  });

  test('sucesso fica em memo: a mesma chave devolve o mesmo objeto', () async {
    final source = _RecordingCatalogSource.ok();
    final container = _createContainer(source);
    const key = HomeRemoteSearchKey(query: 'agua', page: 1);

    final sub = container.listen(homeRemoteSearchProvider(key), (_, _) {});
    final first = await container.read(homeRemoteSearchProvider(key).future);

    // Sem ouvintes: só o `keepAlive` do sucesso segura a instância.
    sub.close();
    await pumpEventQueue();

    final second = await container.read(homeRemoteSearchProvider(key).future);

    expect(identical(first, second), isTrue);
    expect(source.searchCalls, 1);
  });

  test('falha não fica em memo nem é re-tentada sozinha', () async {
    var calls = 0;
    final source = _RecordingCatalogSource((_, _) async {
      calls++;
      throw Exception('coldigom indisponível');
    });
    final container = _createContainer(source);
    const key = HomeRemoteSearchKey(query: 'agua', page: 1);

    final sub = container.listen(homeRemoteSearchProvider(key), (_, _) {});
    await expectLater(
      container.read(homeRemoteSearchProvider(key).future),
      throwsA(isA<Exception>()),
    );
    await pumpEventQueue();

    // `retry: (_, _) => null` desliga o backoff do Riverpod 3.
    expect(calls, 1);
    expect(container.read(homeRemoteSearchProvider(key)).hasError, isTrue);

    sub.close();
  });

  test('SearchCancelledException nunca vira AsyncError visível', () async {
    final source = _RecordingCatalogSource((_, _) async {
      throw const SearchCancelledException();
    });
    final container = _createContainer(source);
    const key = HomeRemoteSearchKey(query: 'agua', page: 1);

    container.listen(homeRemoteSearchProvider(key), (_, _) {});
    await pumpEventQueue();

    final remote = container.read(homeRemoteSearchProvider(key));
    expect(remote.hasError, isFalse);
    expect(remote.value?.groups, isEmpty);
  });
}
