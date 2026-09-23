import 'dart:async';

import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/await_coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../helpers/praise_share_fixtures.dart';

/// Catálogo local dirigido pelo teste: trocá-lo re-hidrata, como o sync real
/// faz ao substituir o catálogo.
class _LocalCatalog extends Notifier<ColdigomSearchIndex> {
  @override
  ColdigomSearchIndex build() => ColdigomSearchIndex.empty;

  void replace(ColdigomSearchIndex index) => state = index;
}

final _localCatalogProvider =
    NotifierProvider<_LocalCatalog, ColdigomSearchIndex>(_LocalCatalog.new);

/// Dá um `Ref` estável ao helper — um `Provider` sem `watch` não reconstrói.
final _awaitProbe =
    Provider<Future<ColdigomSearchIndex> Function(Duration timeout)>(
      (ref) =>
          (timeout) => awaitColdigomSearchIndex(ref, timeout: timeout),
    );

const _syncFailed = ColdigomCatalogSyncFailed('sem rede');

/// O fake partilhado, com o `sync()` retido até [release] — um sync em voo.
class _HeldSync extends FakeColdigomCatalogSyncNotifier {
  _HeldSync(super.initial, super.syncResult);

  final _held = Completer<void>();

  void release() => _held.complete();

  @override
  Future<ColdigomCatalogSyncResult> sync() async {
    await _held.future;
    return super.sync();
  }
}

void main() {
  final hydrated = praiseIndex([
    praiseGroup(
      praiseId: 'p1',
      shortId: '0a1',
      audios: [
        praiseAudio(
          praiseId: 'p1',
          audioId: praiseMaterialId('p1', 'audio.mp3'),
        ),
      ],
    ),
  ]);

  ProviderContainer container({
    required FakeColdigomCatalogSyncNotifier sync,
    Future<ColdigomSearchIndex> Function(Ref ref)? hydration,
  }) {
    final c = ProviderContainer(
      overrides: [
        coldigomCatalogHydrationProvider.overrideWith(
          hydration ?? (ref) async => ref.watch(_localCatalogProvider),
        ),
        coldigomCatalogSyncProvider.overrideWith(() => sync),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('índice já hidratado volta na hora, sem sync', () async {
    final sync = FakeColdigomCatalogSyncNotifier();
    final c = ProviderContainer(
      overrides: catalogIndexOverrides(hydrated, sync: sync),
    );
    addTearDown(c.dispose);
    await c.read(coldigomCatalogHydrationProvider.future);

    expect(
      await c.read(_awaitProbe)(const Duration(seconds: 1)),
      same(hydrated),
    );
    expect(sync.syncCalls, 0);
  });

  test(
    'índice vazio: pede sync e devolve o índice assim que ele enche',
    () async {
      final sync = FakeColdigomCatalogSyncNotifier();
      final c = container(sync: sync);
      await c.read(coldigomCatalogHydrationProvider.future);

      final pending = c.read(_awaitProbe)(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      c.read(_localCatalogProvider.notifier).replace(hydrated);

      expect(await pending, same(hydrated));
      expect(sync.syncCalls, 1);
    },
  );

  test('prazo esgotado devolve o índice vazio', () async {
    final sync = FakeColdigomCatalogSyncNotifier();
    final c = container(sync: sync);
    await c.read(coldigomCatalogHydrationProvider.future);

    final result = await c.read(_awaitProbe)(const Duration(milliseconds: 50));

    expect(result.isEmpty, isTrue);
    expect(sync.syncCalls, 1);
  });

  test('índice vazio e o sync falha: devolve o vazio sem esperar o prazo', () {
    fakeAsync((async) {
      final sync = FakeColdigomCatalogSyncNotifier(
        const ColdigomCatalogSyncState(lastResult: ColdigomCatalogSyncNoop()),
        _syncFailed,
      );
      final c = container(sync: sync);
      c.read(coldigomCatalogHydrationProvider);
      async.elapse(Duration.zero);

      ColdigomSearchIndex? result;
      c
          .read(_awaitProbe)(sharedPlaylistCatalogTimeout)
          .then((index) => result = index);
      async.elapse(Duration.zero);

      expect(result, isNotNull, reason: 'não espera os 20 s do prazo');
      expect(result!.isEmpty, isTrue);
      expect(async.elapsed, Duration.zero);
      expect(sync.syncCalls, 1);
    });
  });

  test('sync falha com a hidratação em curso: espera o catálogo local '
      '(arranque a frio offline)', () {
    fakeAsync((async) {
      final local = Completer<ColdigomSearchIndex>();
      final sync = FakeColdigomCatalogSyncNotifier(
        const ColdigomCatalogSyncState(),
        _syncFailed,
      );
      final c = container(sync: sync, hydration: (ref) => local.future);

      ColdigomSearchIndex? result;
      c
          .read(_awaitProbe)(sharedPlaylistCatalogTimeout)
          .then((index) => result = index);
      async.elapse(Duration.zero);
      expect(result, isNull, reason: 'o Isar ainda está a hidratar');
      expect(sync.syncCalls, 1);

      local.complete(hydrated);
      async.elapse(Duration.zero);

      expect(result, same(hydrated));
      expect(async.elapsed, Duration.zero);
    });
  });

  test(
    'falha antiga (do boot) não encerra a espera: vale o sync pedido agora',
    () {
      fakeAsync((async) {
        final sync = FakeColdigomCatalogSyncNotifier(
          const ColdigomCatalogSyncState(lastResult: _syncFailed),
          const ColdigomCatalogSyncReplaced(1),
        );
        final c = container(sync: sync);
        c.read(coldigomCatalogHydrationProvider);
        async.elapse(Duration.zero);
        expect(c.read(catalogIndexStatusProvider), CatalogIndexStatus.failed);

        ColdigomSearchIndex? result;
        c
            .read(_awaitProbe)(sharedPlaylistCatalogTimeout)
            .then((index) => result = index);
        async.elapse(Duration.zero);
        expect(result, isNull);
        expect(sync.syncCalls, 1);

        c.read(_localCatalogProvider.notifier).replace(hydrated);
        async.elapse(Duration.zero);

        expect(result, same(hydrated));
      });
    },
  );

  test('falha antiga que aparece com o sync em voo não encerra a espera; '
      'o sync pedido falhando, sim', () {
    fakeAsync((async) {
      final local = Completer<ColdigomSearchIndex>();
      final sync = _HeldSync(
        const ColdigomCatalogSyncState(lastResult: _syncFailed),
        _syncFailed,
      );
      final c = container(sync: sync, hydration: (ref) => local.future);

      ColdigomSearchIndex? result;
      c
          .read(_awaitProbe)(sharedPlaylistCatalogTimeout)
          .then((index) => result = index);
      async.elapse(Duration.zero);

      // Sem catálogo local: o status vira `failed` pela falha do boot,
      // mas o sync pedido ainda não terminou.
      local.complete(ColdigomSearchIndex.empty);
      async.elapse(Duration.zero);
      expect(c.read(catalogIndexStatusProvider), CatalogIndexStatus.failed);
      expect(result, isNull);

      // O status continua `failed` (não notifica): vale a releitura no
      // fim do sync.
      sync.release();
      async.elapse(Duration.zero);

      expect(result, isNotNull, reason: 'não espera os 20 s do prazo');
      expect(result!.isEmpty, isTrue);
      expect(async.elapsed, Duration.zero);
      expect(sync.syncCalls, 1);
    });
  });
}
