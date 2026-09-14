import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/data/providers/catalog_source_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/domain/ports/catalog_source.dart';
import 'package:coldigui/features/catalog/domain/ports/search_cancellation.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_remote_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _louvor({required String nome, required String numero}) =>
    Louvor.fromManifest(
      nome: nome,
      numero: numero,
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '$numero.pdf',
      pdfId: 'id-$numero',
    );

/// Fonte de catálogo que conta as buscas remotas e responde pelo roteiro.
class _RecordingCatalogSource implements CatalogSource {
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
  List<LouvorGroup> searchLocal(CatalogQuery query) => const [];

  @override
  Future<CatalogSearchPage> search(
    CatalogQuery query, {
    SearchCancellation? cancellation,
  }) {
    queries.add(query);
    return _respond(query);
  }

  @override
  Future<LouvorGroup?> groupById(String groupId) async => null;

  @override
  Future<CatalogMaterial?> materialById(String materialId) async => null;

  @override
  Future<LouvorGroup?> groupForMaterial(String materialId) async => null;
}

/// Manifest fixo que o teste pode re-emitir (refresh de fundo).
class _MutableManifestNotifier extends LouvoresManifestNotifier {
  _MutableManifestNotifier(this._initial);

  final LouvoresManifest _initial;

  @override
  Future<LouvoresManifest> build() async => _initial;

  void emit(LouvoresManifest manifest) => state = AsyncData(manifest);
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final catalog = [
    _louvor(nome: 'Aleluia', numero: '001'),
    _louvor(nome: 'São João', numero: '002'),
  ];

  ProviderContainer createContainer(
    CatalogSource source, {
    _MutableManifestNotifier? manifest,
    List<Override> extra = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        louvoresManifestProvider.overrideWith(
          () =>
              manifest ??
              _MutableManifestNotifier(LouvoresManifest.fromLouvores(catalog)),
        ),
        catalogSourceProvider.overrideWithValue(source),
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
    expect(state.hasNextPage, isFalse);
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

  test(
    'grupos concatenam local (PLPCG) e remoto (Coldigom) nessa ordem',
    () async {
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
    },
  );

  test('grupo remoto com o mesmo groupId de um local não duplica (provisório até o plano 3)', () async {
    // Louvor local 'Aleluia' (numero '001') gera groupId '001:aleluia'
    // (LouvorGroupId.compute); um grupo remoto com o mesmo id simula o
    // Coldigom ainda devolvendo algo que o índice local já cobre.
    final duplicateOfLocal = LouvorGroup(
      groupId: '001:aleluia',
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
    expect(state.remoteGroups, isNotEmpty);
    expect(state.groups.length, state.localGroups.length);
    expect(state.groups.where((g) => g.groupId == '001:aleluia').length, 1);
  });

  test('página 2 usa outra chave; voltar à 1 reusa o memo', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    final pageOne = container.read(homeSearchStateProvider).remote.value;
    expect(pageOne, isNotNull);
    expect(source.searchCalls, 1);

    container.read(homeSearchPageProvider.notifier).next();
    await pumpEventQueue();

    expect(container.read(homeSearchStateProvider).page, 2);
    expect(source.queries.last.page, 2);
    expect(source.searchCalls, 2);

    container.read(homeSearchPageProvider.notifier).previous();
    await pumpEventQueue();

    final backToOne = container.read(homeSearchStateProvider).remote.value;
    expect(identical(pageOne, backToOne), isTrue);
    expect(source.searchCalls, 2);
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
      // Os resultados PLPCG continuam visíveis apesar da falha remota.
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

    container.read(catalogFiltersProvider.notifier).toggleMaterial('Partitura');
    await pumpEventQueue();

    expect(container.read(homeSearchStateProvider).localGroups, isEmpty);
    expect(source.searchCalls, 1);
  });

  test('novo manifest re-deriva só a busca local', () async {
    final manifest = _MutableManifestNotifier(
      LouvoresManifest.fromLouvores(catalog),
    );
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(source, manifest: manifest);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    expect(source.searchCalls, 1);
    final before = container.read(homeSearchStateProvider).localGroups;
    expect(before, isNotEmpty);

    manifest.emit(
      LouvoresManifest.fromLouvores([
        ...catalog,
        _louvor(nome: 'Aleluia nova', numero: '003'),
      ]),
    );
    await pumpEventQueue();

    final after = container.read(homeSearchStateProvider).localGroups;
    expect(after.length, greaterThan(before.length));
    expect(source.searchCalls, 1);
  });

  test('trocar a query volta a página para 1', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    container.read(homeSearchPageProvider.notifier).next();
    await pumpEventQueue();
    expect(container.read(homeSearchStateProvider).page, 2);

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('joão');
    await pumpEventQueue();

    expect(container.read(homeSearchStateProvider).page, 1);
    // A página volta a 1 **antes** de a remota ser pedida: nunca sai um
    // request para ('joão', 2) — só o de 'aleluia' p.1, 'aleluia' p.2 e
    // 'joão' p.1.
    expect(source.searchCalls, 3);
    expect(source.queries.last.page, 1);
    expect(source.queries.last.text, 'joão');
  });

  test('mudar o filtro volta a página para 1 sem re-buscar a remota', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();
    expect(source.searchCalls, 1);

    container.read(catalogFiltersProvider.notifier).toggleMaterial('Partitura');
    await pumpEventQueue();

    expect(container.read(homeSearchStateProvider).page, 1);
    // Página já era 1: a chave remota não mudou, então nada foi re-buscado.
    expect(source.searchCalls, 1);
  });
}
