import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/ports/search_cancellation.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_remote_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_data_providers.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_source_provider.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/domain/usecases/adopt_coldigom_search_novelties.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

/// Fonte Coldigom que conta as buscas remotas e responde pelo roteiro.
class _RecordingCatalogSource extends ColdigomCatalogSource {
  _RecordingCatalogSource(this._respond);

  factory _RecordingCatalogSource.ok() {
    return _RecordingCatalogSource(
      (query) async => CatalogSearchPage(groups: const [], page: query.page),
    );
  }

  final Future<CatalogSearchPage> Function(CatalogQuery query) _respond;

  final queries = <CatalogQuery>[];

  int get searchCalls => queries.length;

  @override
  Future<CatalogSearchPage> search(
    CatalogQuery query, {
    SearchCancellation? cancellation,
  }) {
    queries.add(query);
    return _respond(query);
  }
}

/// Regista o que a Home pediu para adotar; devolve os ids como adotados.
class _RecordingAdopter extends AdoptColdigomSearchNovelties {
  _RecordingAdopter()
    : super(const ColdigomCatalogLocalDatasource.unavailable());

  final calls = <List<String>>[];
  Set<String> knownSeen = const {};

  @override
  Future<Set<String>> call(
    Iterable<LouvorGroup> remoteGroups, {
    required Set<String> knownPraiseIds,
  }) async {
    knownSeen = knownPraiseIds;
    final ids = [for (final g in remoteGroups) g.groupId];
    calls.add(ids);
    return ids.toSet();
  }
}

/// Conta os `sync()` disparados pela pesquisa; não toca na rede.
class _CountingSync extends ColdigomCatalogSyncNotifier {
  var calls = 0;

  @override
  ColdigomCatalogSyncState build() => const ColdigomCatalogSyncState();

  @override
  Future<ColdigomCatalogSyncResult> sync() async {
    calls++;
    return const ColdigomCatalogSyncNoop();
  }
}

LouvorGroup _coldigomGroup(String id) => LouvorGroup(
  groupId: id,
  numero: '900',
  nome: 'Coldigom $id',
  sections: const [],
  coldigomMeta: const ColdigomPraiseMetadata(name: 'Coldigom'),
);

/// Catálogo local dos testes: «Aleluia» (001) e «São João» (002).
final _defaultIndex = catalogIndexOf([
  catalogGroup(praiseId: 'p-001', number: '001', name: 'Aleluia'),
  catalogGroup(praiseId: 'p-002', number: '002', name: 'São João'),
]);

/// Índice Coldigom que o teste consegue trocar no meio do caminho (fix
/// round final, achado 4c) — `coldigomSearchIndexProvider` é um `Provider`
/// simples, então a mutabilidade entra por baixo, via `overrideWith`.
class _MutableColdigomIndexNotifier extends Notifier<ColdigomSearchIndex> {
  @override
  ColdigomSearchIndex build() => _defaultIndex;

  void update(ColdigomSearchIndex index) => state = index;
}

final _mutableColdigomIndexProvider =
    NotifierProvider<_MutableColdigomIndexNotifier, ColdigomSearchIndex>(
      _MutableColdigomIndexNotifier.new,
    );

void main() {
  late SharedPreferences prefs;
  late _RecordingAdopter adopter;
  late _CountingSync syncNotifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    adopter = _RecordingAdopter();
    syncNotifier = _CountingSync();
  });

  ProviderContainer createContainer(
    ColdigomCatalogSource source, {
    bool online = true,
    ColdigomSearchIndex? index,
    // Por padrão a hidratação já "terminou" com o mesmo `index` — os testes
    // do gate antes da hidratação e da invalidação por `syncAfterAdoption`
    // passam o próprio override (Riverpod rejeita sobrescrever o mesmo
    // provider duas vezes).
    Override? hydrationOverride,
    Override? searchIndexOverride,
    List<Override> extra = const [],
  }) {
    final effectiveIndex = index ?? _defaultIndex;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        coldigomCatalogSourceProvider.overrideWithValue(source),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
        adoptColdigomSearchNoveltiesProvider.overrideWithValue(adopter),
        coldigomCatalogSyncProvider.overrideWith(() => syncNotifier),
        hydrationOverride ??
            coldigomCatalogHydrationProvider.overrideWith(
              (ref) async => effectiveIndex,
            ),
        searchIndexOverride ??
            coldigomSearchIndexProvider.overrideWithValue(effectiveIndex),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Mantém o estado vivo (a família remota é `autoDispose`).
  void keepStateAlive(ProviderContainer container) {
    final sub = container.listen(homeSearchStateProvider, (_, _) {});
    addTearDown(sub.close);
  }

  test('query vazia: estado pronto, sem rede e sem loading', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);

    expect(state.isEmptyQuery, isTrue);
    expect(state.groups, isEmpty);
    expect(state.remoteLoading, isFalse);
    expect(state.remoteFailed, isFalse);
    expect(state.freshness, SearchFreshness.updated);
    expect(state.remote.hasValue, isTrue);
    expect(source.searchCalls, 0);
  });

  test('a query crua só chega ao estado depois de 300 ms', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container.read(homeSearchQueryProvider.notifier).setQuery('alel');
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(container.read(homeSearchStateProvider).query, isEmpty);
    expect(source.searchCalls, 0);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    await pumpEventQueue();

    expect(container.read(homeSearchStateProvider).query, 'alel');
    expect(container.read(homeSearchStateProvider).localGroups, isNotEmpty);
    expect(source.searchCalls, 1);
  });

  test('grupos concatenam local e remoto nessa ordem', () async {
    final coldigomGroup = LouvorGroup(
      groupId: 'coldigom-1',
      numero: '900',
      nome: 'Coldigom',
      sections: const [],
    );
    final source = _RecordingCatalogSource(
      (query) async =>
          CatalogSearchPage(groups: [coldigomGroup], page: query.page),
    );
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(state.localGroups, isNotEmpty);
    expect(state.groups.last.groupId, 'coldigom-1');
    expect(state.groups.length, state.localGroups.length + 1);
  });

  test('grupo remoto com o mesmo groupId de um local não duplica', () async {
    // Um grupo remoto com o id de um praise que o índice já devolveu não
    // duplica: `newGroups` filtra ids já locais.
    final duplicateOfLocal = LouvorGroup(
      groupId: 'p-001',
      numero: '001',
      nome: 'Aleluia (remoto)',
      sections: const [],
    );
    final source = _RecordingCatalogSource(
      (query) async =>
          CatalogSearchPage(groups: [duplicateOfLocal], page: query.page),
    );
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(state.localGroups, isNotEmpty);
    expect(state.remote.value?.groups, isNotEmpty);
    expect(state.newGroupIds, isEmpty);
    expect(state.groups.length, state.localGroups.length);
    expect(state.groups.where((g) => g.groupId == 'p-001').length, 1);
  });

  test(
    'erro remoto marca remoteFailed; o retry re-busca a mesma chave',
    () async {
      var calls = 0;
      final source = _RecordingCatalogSource((query) async {
        calls++;
        if (calls == 1) throw Exception('coldigom indisponível');
        return CatalogSearchPage(groups: const [], page: query.page);
      });
      final container = createContainer(source);
      keepStateAlive(container);
      await pumpEventQueue();

      container
          .read(homeSearchDebouncedQueryProvider.notifier)
          .setImmediate('aleluia');
      await pumpEventQueue();

      expect(container.read(homeSearchStateProvider).remoteFailed, isTrue);
      // Os resultados locais continuam visíveis apesar da falha remota.
      expect(container.read(homeSearchStateProvider).groups, isNotEmpty);

      container.invalidate(
        homeRemoteSearchProvider(
          const HomeRemoteSearchKey(query: 'aleluia', page: 1),
        ),
      );
      await pumpEventQueue();

      expect(container.read(homeSearchStateProvider).remoteFailed, isFalse);
      expect(calls, 2);
    },
  );

  test('mudar o filtro re-deriva só a busca local', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    expect(source.searchCalls, 1);
    expect(container.read(homeSearchStateProvider).localGroups, isNotEmpty);

    container.read(catalogFiltersProvider.notifier).toggleTonality('Sem tom');
    await pumpEventQueue();

    expect(container.read(homeSearchStateProvider).localGroups, isEmpty);
    expect(source.searchCalls, 1);
  });

  test('novo índice re-deriva só a busca local', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(
      source,
      searchIndexOverride: coldigomSearchIndexProvider.overrideWith(
        (ref) => ref.watch(_mutableColdigomIndexProvider),
      ),
    );
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    expect(source.searchCalls, 1);
    final before = container.read(homeSearchStateProvider).localGroups;
    expect(before, isNotEmpty);

    container
        .read(_mutableColdigomIndexProvider.notifier)
        .update(
          catalogIndexOf([
            catalogGroup(praiseId: 'p-001', number: '001', name: 'Aleluia'),
            catalogGroup(
              praiseId: 'p-003',
              number: '003',
              name: 'Aleluia nova',
            ),
          ]),
        );
    await pumpEventQueue();

    final after = container.read(homeSearchStateProvider).localGroups;
    expect(after.length, greaterThan(before.length));
    expect(source.searchCalls, 1);
  });

  test(
    'remoto igual ao local → updated, sem novos, sem adoção nem sync',
    () async {
      final coldigom = _coldigomGroup('cold-1');
      // Índice local conhece cold-1: a busca local devolve-o e o remoto só confirma.
      final source = _RecordingCatalogSource(
        (query) async =>
            CatalogSearchPage(groups: [coldigom], page: query.page),
      );
      final container = createContainer(
        source,
        index: ColdigomSearchIndex.build([
          ColdigomIndexedPraise.build(
            praiseId: 'cold-1',
            numero: '900',
            nome: 'Coldigom cold-1',
            searchTokens: 'coldigom cold-1 900',
            group: coldigom,
          ),
        ]),
      );
      keepStateAlive(container);
      await pumpEventQueue();

      container
          .read(homeSearchDebouncedQueryProvider.notifier)
          .setImmediate('coldigom');
      await pumpEventQueue();

      final state = container.read(homeSearchStateProvider);
      expect(state.freshness, SearchFreshness.updated);
      expect(state.newGroupIds, isEmpty);
      expect(state.groups.map((g) => g.groupId), contains('cold-1'));
      // Sem candidatos (o índice já conhecia cold-1), o adopter nem é
      // chamado — poupa uma volta à toa a cada página remota que só
      // confirma o que a Home já sabia.
      expect(adopter.calls, isEmpty);
      expect(syncNotifier.calls, 0);
    },
  );

  test(
    'remoto com extra → updatedWithNew, extra no fim, adoção e sync disparados',
    () async {
      final source = _RecordingCatalogSource(
        (query) async => CatalogSearchPage(
          groups: [_coldigomGroup('cold-2'), _coldigomGroup('cold-1')],
          page: query.page,
        ),
      );
      final container = createContainer(source);
      keepStateAlive(container);
      await pumpEventQueue();

      container
          .read(homeSearchDebouncedQueryProvider.notifier)
          .setImmediate('aleluia');
      await pumpEventQueue();

      final state = container.read(homeSearchStateProvider);
      expect(state.freshness, SearchFreshness.updatedWithNew);
      expect(state.newCount, 2);
      expect(
        state.groups
            .map((g) => g.groupId)
            .toList()
            .sublist(state.localGroups.length),
        ['cold-2', 'cold-1'],
      );
      expect(state.localGroups.first.groupId, isNot('cold-2'));
      expect(adopter.calls.single, ['cold-2', 'cold-1']);
      expect(adopter.knownSeen, {'p-001', 'p-002'});
      expect(syncNotifier.calls, 1);
      expect(source.queries.single.page, 1);
    },
  );

  test(
    '«novo» é novo pro catálogo, não só pra esta busca: cold-1 já está no '
    'índice (outros tokens, a busca local textual não o achou) e não leva '
    'chip nem conta — cold-9 sim; os dois ficam em groups (§6.3, ruling)',
    () async {
      final cold1 = _coldigomGroup('cold-1');
      final cold9 = _coldigomGroup('cold-9');
      final source = _RecordingCatalogSource(
        (query) async =>
            CatalogSearchPage(groups: [cold1, cold9], page: query.page),
      );
      final container = createContainer(
        source,
        // Índice conhece cold-1 mas com tokens que a query não bate: ele
        // não aparece em `localGroups` (busca textual falha), só via
        // `knownIds` — exatamente o caso que `newGroups` sozinho não cobria.
        index: ColdigomSearchIndex.build([
          ColdigomIndexedPraise.build(
            praiseId: 'cold-1',
            numero: '900',
            nome: 'Coldigom cold-1',
            searchTokens: 'outroassunto',
            group: cold1,
          ),
        ]),
      );
      keepStateAlive(container);
      await pumpEventQueue();

      container
          .read(homeSearchDebouncedQueryProvider.notifier)
          .setImmediate('exclusivoremoto');
      await pumpEventQueue();

      final state = container.read(homeSearchStateProvider);
      expect(state.localGroups, isEmpty);
      expect(state.groups.map((g) => g.groupId).toList(), ['cold-1', 'cold-9']);
      expect(state.newGroupIds, {'cold-9'});
      expect(state.newCount, 1);
      expect(state.freshness, SearchFreshness.updatedWithNew);
      expect(adopter.calls.single, ['cold-9']);
      expect(syncNotifier.calls, 1);
    },
  );

  test('remoto falha → failed com a lista local intacta', () async {
    final source = _RecordingCatalogSource(
      (_) async => throw Exception('boom'),
    );
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(state.freshness, SearchFreshness.failed);
    expect(state.localGroups, isNotEmpty);
    expect(state.groups.length, state.localGroups.length);
    expect(adopter.calls, isEmpty);
  });

  test('sem rede → offline sem chamar o remoto', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(source, online: false);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(state.freshness, SearchFreshness.offline);
    expect(state.localGroups, isNotEmpty);
    expect(state.remoteLoading, isFalse);
    expect(source.searchCalls, 0);
  });

  test(
    'os «novos» do remoto passam pelo mesmo filtro da lista local',
    () async {
      final emDm = LouvorGroup(
        groupId: 'cold-dm',
        numero: '901',
        nome: 'Em Dm',
        sections: const [],
        coldigomMeta: const ColdigomPraiseMetadata(
          name: 'Em Dm',
          tonality: 'Dm',
        ),
      );
      final source = _RecordingCatalogSource(
        (query) async => CatalogSearchPage(
          groups: [_coldigomGroup('cold-2'), emDm],
          page: query.page,
        ),
      );
      final container = createContainer(source);
      keepStateAlive(container);
      await pumpEventQueue();

      container.read(catalogFiltersProvider.notifier).toggleTonality('Dm');
      container
          .read(homeSearchDebouncedQueryProvider.notifier)
          .setImmediate('aleluia');
      await pumpEventQueue();

      final state = container.read(homeSearchStateProvider);
      expect(state.newGroups.map((g) => g.groupId), ['cold-dm']);
    },
  );

  test('mudar o filtro não re-busca a remota', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();
    expect(source.searchCalls, 1);

    container.read(catalogFiltersProvider.notifier).toggleTonality('Sem tom');
    await pumpEventQueue();

    expect(source.searchCalls, 1);
  });

  test(
    'remoto em voo: checking com a lista local visível; updated ao completar',
    () async {
      final completer = Completer<CatalogSearchPage>();
      final source = _RecordingCatalogSource((_) => completer.future);
      final container = createContainer(source);
      keepStateAlive(container);
      await pumpEventQueue();

      container
          .read(homeSearchDebouncedQueryProvider.notifier)
          .setImmediate('aleluia');
      await pumpEventQueue();

      final checking = container.read(homeSearchStateProvider);
      expect(checking.freshness, SearchFreshness.checking);
      expect(checking.localGroups, isNotEmpty);
      expect(checking.groups, checking.localGroups);

      completer.complete(const CatalogSearchPage(groups: [], page: 1));
      await pumpEventQueue();

      expect(
        container.read(homeSearchStateProvider).freshness,
        SearchFreshness.updated,
      );
    },
  );

  test('retry após falha passa por checking antes de updated', () async {
    var calls = 0;
    final gate = Completer<void>();
    final source = _RecordingCatalogSource((query) async {
      calls++;
      if (calls == 1) throw Exception('coldigom indisponível');
      await gate.future;
      return CatalogSearchPage(groups: const [], page: query.page);
    });
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();
    expect(
      container.read(homeSearchStateProvider).freshness,
      SearchFreshness.failed,
    );

    container.invalidate(
      homeRemoteSearchProvider(
        const HomeRemoteSearchKey(query: 'aleluia', page: 1),
      ),
    );
    // O segundo `search` ainda está preso em `gate`: o estado já trocou de
    // `failed` para `checking`, não indo direto para `updated`.
    expect(
      container.read(homeSearchStateProvider).freshness,
      SearchFreshness.checking,
    );

    gate.complete();
    await pumpEventQueue();

    expect(
      container.read(homeSearchStateProvider).freshness,
      SearchFreshness.updated,
    );
    expect(calls, 2);
  });

  test('índice chega depois: quando o catálogo aprende cold-9, o chip some e '
      'o card não duplica', () async {
    final cold9 = _coldigomGroup('cold-9');
    final source = _RecordingCatalogSource(
      (query) async => CatalogSearchPage(groups: [cold9], page: query.page),
    );
    final container = createContainer(
      source,
      searchIndexOverride: coldigomSearchIndexProvider.overrideWith(
        (ref) => ref.watch(_mutableColdigomIndexProvider),
      ),
    );
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    var state = container.read(homeSearchStateProvider);
    expect(state.newGroupIds, {'cold-9'});
    expect(state.groups.where((g) => g.groupId == 'cold-9'), hasLength(1));

    // O sync que a adoção disparou terminou e re-hidratou: o índice agora
    // conhece cold-9.
    container
        .read(_mutableColdigomIndexProvider.notifier)
        .update(
          ColdigomSearchIndex.build([
            ColdigomIndexedPraise.build(
              praiseId: 'cold-9',
              numero: '900',
              nome: 'Coldigom cold-9',
              searchTokens: 'coldigom cold-9 900',
              group: cold9,
            ),
          ]),
        );
    await pumpEventQueue();

    state = container.read(homeSearchStateProvider);
    expect(state.newGroupIds, isEmpty);
    expect(state.groups.where((g) => g.groupId == 'cold-9'), hasLength(1));
  });

  test(
    'praise em catalogIds mas fora de praiseIds (já adotado, sem entrar no '
    'índice de busca — ex. só-YouTube) aparece no fim sem chip «novo»',
    () async {
      final cold9 = _coldigomGroup('cold-9');
      final source = _RecordingCatalogSource(
        (query) async => CatalogSearchPage(groups: [cold9], page: query.page),
      );
      final container = createContainer(
        source,
        index: ColdigomSearchIndex.build(const [], catalogIds: {'cold-9'}),
      );
      keepStateAlive(container);
      await pumpEventQueue();

      container
          .read(homeSearchDebouncedQueryProvider.notifier)
          .setImmediate('exclusivoremoto');
      await pumpEventQueue();

      final state = container.read(homeSearchStateProvider);
      expect(state.localGroups, isEmpty);
      expect(state.groups.map((g) => g.groupId), ['cold-9']);
      expect(state.newGroupIds, isEmpty);
      expect(state.freshness, SearchFreshness.updated);
    },
  );

  test('extras não levam chip nem contam como novo enquanto a hidratação '
      'ainda não terminou (evita «N novos» transitório no boot)', () async {
    final cold9 = _coldigomGroup('cold-9');
    final source = _RecordingCatalogSource(
      (query) async => CatalogSearchPage(groups: [cold9], page: query.page),
    );
    final container = createContainer(
      source,
      hydrationOverride: coldigomCatalogHydrationProvider.overrideWith(
        (ref) => Completer<ColdigomSearchIndex>().future,
      ),
    );
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(state.freshness, SearchFreshness.updated);
    expect(state.newGroupIds, isEmpty);
    expect(state.groups.map((g) => g.groupId), contains('cold-9'));
  });

  test('adoção sem novo catálogo (sync devolve Noop) ainda assim re-hidrata: '
      'o Isar já tem as linhas adotadas, só faltava reler', () async {
    var hydrationBuilds = 0;
    final cold9 = _coldigomGroup('cold-9');
    final source = _RecordingCatalogSource(
      (query) async => CatalogSearchPage(groups: [cold9], page: query.page),
    );
    final container = createContainer(
      source,
      hydrationOverride: coldigomCatalogHydrationProvider.overrideWith((
        ref,
      ) async {
        hydrationBuilds++;
        return ColdigomSearchIndex.empty;
      }),
    );
    keepStateAlive(container);
    final hydrationSub = container.listen(
      coldigomCatalogHydrationProvider,
      (_, _) {},
    );
    addTearDown(hydrationSub.close);
    await pumpEventQueue();
    expect(hydrationBuilds, 1);

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    expect(adopter.calls.single, ['cold-9']);
    // `_CountingSync.sync()` devolve `Noop`: `syncAfterAdoption` invalida
    // a hidratação mesmo assim.
    expect(hydrationBuilds, 2);
  });
}
