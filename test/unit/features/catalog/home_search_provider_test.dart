import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/domain/ports/search_cancellation.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_worker.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/domain/repositories/coldigom_search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

/// Repositório coldigom cujo comportamento por chamada é controlado pelo
/// teste — permite simular "falha, depois sucesso" na mesma instância.
class _ScriptedColdigomRepo implements ColdigomSearchRepository {
  _ScriptedColdigomRepo(this._behaviors);

  final List<Future<ColdigomSearchResult> Function()> _behaviors;
  var callCount = 0;

  @override
  Future<ColdigomSearchResult> search(
    String query, {
    int page = 1,
    SearchCancellation? cancellation,
  }) {
    final index = callCount < _behaviors.length
        ? callCount
        : _behaviors.length - 1;
    callCount++;
    return _behaviors[index]();
  }

  @override
  Future<ColdigomBrowseResult> browse(ColdigomBrowseQuery query) async {
    return const ColdigomBrowseResult(
      groups: [],
      louvores: [],
      page: 1,
      limit: 10,
      totalItems: 0,
      totalPages: 0,
    );
  }
}

Future<ColdigomSearchResult> _throwing() async {
  throw Exception('coldigom indisponível');
}

Future<ColdigomSearchResult> _empty() async => const ColdigomSearchResult(
  groups: [],
  louvores: [],
  page: 1,
  hasNextPage: false,
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer(ColdigomSearchRepository repo) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
        coldigomSearchRepositoryProvider.overrideWithValue(repo),
        homeSearchPipelineExecutorProvider.overrideWith(
          (ref) =>
              (input) async => runHomeSearchPipeline(input),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'repositório coldigom lançando marca homeSearchColdigomErrorProvider',
    () async {
      final repo = _ScriptedColdigomRepo([_throwing]);
      final container = createContainer(repo);

      // Garante que o driver está construído (registra os `ref.listen`) e
      // deixa os disparos iniciais (`fireImmediately` de query vazia e do
      // manifest ainda carregando) assentarem antes da busca real do teste —
      // senão eles competem pelo mesmo `_generation` e consomem os
      // comportamentos roteirizados do fake repo.
      container.read(homeSearchPipelineDriverProvider);
      await pumpEventQueue();

      container
          .read(homeSearchDebouncedQueryProvider.notifier)
          .setImmediate('agua');
      await pumpEventQueue();

      expect(container.read(homeSearchColdigomErrorProvider), isTrue);
      expect(container.read(homeSearchColdigomGroupsDataProvider), isEmpty);
    },
  );

  test('busca bem-sucedida mantém a flag de erro em false', () async {
    final repo = _ScriptedColdigomRepo([_empty]);
    final container = createContainer(repo);

    container.read(homeSearchPipelineDriverProvider);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('agua');
    await pumpEventQueue();

    expect(container.read(homeSearchColdigomErrorProvider), isFalse);
  });

  test(
    'retry() após falha limpa a flag quando a nova tentativa é bem-sucedida',
    () async {
      final repo = _ScriptedColdigomRepo([_throwing, _empty]);
      final container = createContainer(repo);

      container.read(homeSearchPipelineDriverProvider);
      await pumpEventQueue();

      container
          .read(homeSearchDebouncedQueryProvider.notifier)
          .setImmediate('agua');
      await pumpEventQueue();

      expect(container.read(homeSearchColdigomErrorProvider), isTrue);

      container.read(homeSearchPipelineDriverProvider.notifier).retry();
      await pumpEventQueue();

      expect(container.read(homeSearchColdigomErrorProvider), isFalse);
      expect(repo.callCount, 2);
    },
  );

  test('limpar a busca (query vazia) reseta a flag de erro', () async {
    final repo = _ScriptedColdigomRepo([_throwing]);
    final container = createContainer(repo);

    container.read(homeSearchPipelineDriverProvider);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('agua');
    await pumpEventQueue();
    expect(container.read(homeSearchColdigomErrorProvider), isTrue);

    container.read(homeSearchDebouncedQueryProvider.notifier).setImmediate('');
    await pumpEventQueue();

    expect(container.read(homeSearchColdigomErrorProvider), isFalse);
  });
}
