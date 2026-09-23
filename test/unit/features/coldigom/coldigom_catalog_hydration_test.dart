import 'dart:convert';
import 'dart:io';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/network/device_connectivity.dart';
import 'package:coldigui/core/providers/device_connectivity_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_source_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

class _Online implements DeviceConnectivity {
  _Online(this.online);
  final bool online;
  @override
  Future<bool> hasConnection() async => online;
}

class _ScriptedRemote extends ColdigomRemoteDatasource {
  _ScriptedRemote(this._respond) : super(Dio());
  final Future<ColdigomCatalogFetchResult> Function() _respond;
  int calls = 0;
  String? lastIfNoneMatch;
  @override
  Future<ColdigomCatalogFetchResult> fetchCatalog({String? ifNoneMatch}) {
    calls++;
    lastIfNoneMatch = ifNoneMatch;
    return _respond();
  }
}

ColdigomCatalogDto _catalog() => ColdigomCatalogDto.fromJson(
  jsonDecode(
    File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync(),
  ) as Map<String, dynamic>,
);

void main() {
  late Directory tempDir;
  late Isar isar;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = await Directory.systemTemp.createTemp('coldigom_hydration_');
    isar = Isar.open(
      schemas: [ColdigomPraiseCacheSchema],
      directory: tempDir.path,
      name: 'coldigom_hydration_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  ProviderContainer container({
    required _ScriptedRemote remote,
    bool online = true,
    bool isarAvailable = true,
    Duration isarOpenDelay = Duration.zero,
  }) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarInitializerProvider.overrideWith((ref) async {
          if (isarOpenDelay > Duration.zero) {
            await Future<void>.delayed(isarOpenDelay);
          }
          if (!isarAvailable) throw StateError('sem isar');
          return isar;
        }),
        coldigomRemoteDatasourceProvider.overrideWithValue(remote),
        deviceConnectivityProvider.overrideWithValue(_Online(online)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> seed() async {
    final catalog = _catalog();
    await ColdigomCatalogLocalDatasource(isar).replaceAll([
      for (final p in catalog.praises)
        ColdigomPraiseCacheMapper.fromCatalogPraise(
          p,
          kindNames: catalog.kindNames,
        ),
    ]);
  }

  test('hidrata caches e índice a partir do Isar, sem tocar na rede', () async {
    await seed();
    final remote = _ScriptedRemote(
      () async => const ColdigomCatalogNotModified(),
    );
    final c = container(remote: remote, online: false);

    final index = await c.read(coldigomCatalogHydrationProvider.future);

    // p-003 não tem material nenhum (nem letra): não sustenta um grupo e
    // fica fora do índice — mas continua no Isar (`count` = 3), e por isso
    // entra em `catalogIds` mesmo fora de `praiseIds` (§6.2, plano 3).
    expect(index.praiseIds, {'p-001', 'p-002'});
    expect(index.catalogIds, {'p-001', 'p-002', 'p-003'});
    expect(c.read(coldigomLouvoresCacheProvider).length, 1);
    expect(c.read(coldigomAudioTracksCacheProvider).length, 2);
    expect(c.read(coldigomChordMaterialsCacheProvider).length, 1);
    expect(c.read(coldigomGestureMaterialsCacheProvider).length, 1);
    expect(c.read(coldigomYoutubeCacheProvider)['p-001'], hasLength(1));
    expect(c.read(coldigomLyricsCacheProvider).keys, ['p-001']);
    expect(
      c.read(coldigomPraiseMetaCacheProvider)['p-002']!.author,
      'Autor Dois',
    );
    final source = c.read(coldigomCatalogSourceProvider);
    final hits = source.searchLocal(const CatalogQuery(text: 'tempo'));
    expect(hits.single.groupId, 'p-001');
    expect(hits.single.lyrics, isNotNull);
    expect(hits.single.totalMaterials, 6);

    // C4: shortId e ids de material de qualquer tipo apontam para o grupo.
    expect(index.groupByShortId('000')?.groupId, 'p-001');
    expect(index.groupByShortId('0A1')?.groupId, 'p-002');
    for (final id in [
      encodePdfId('assets/praises/p-001/m-pdf.pdf'),
      encodePdfId('assets/praises/p-001/m-chord.chord'),
      encodePdfId('assets/praises/p-001/m-gest.gestures'),
      encodePdfId('assets/praises/p-001/m-mp3.mp3'),
      'lyrics:p-001',
      'yt-1',
    ]) {
      expect(index.groupForMaterialId(id)?.groupId, 'p-001', reason: id);
    }
    expect(
      index
          .groupForMaterialId(encodePdfId('assets/praises/p-002/m-odd.m4a'))
          ?.groupId,
      'p-002',
    );
    expect(remote.calls, 0);
  });

  test(
    'sem Isar: o sync baixa o dump para a memória e o índice hidrata dele',
    () async {
      final remote = _ScriptedRemote(
        () async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
      );
      // Offline: o `requestSyncIfStale` do boot não corre em paralelo com o
      // `sync()` explícito deste teste.
      final c = container(remote: remote, isarAvailable: false, online: false);

      expect(
        (await c.read(coldigomCatalogHydrationProvider.future)).isEmpty,
        isTrue,
      );
      final result = await c.read(coldigomCatalogSyncProvider.notifier).sync();

      expect(result, isA<ColdigomCatalogSyncInMemory>());
      final index = await c.read(coldigomCatalogHydrationProvider.future);
      expect(index.praiseIds, {'p-001', 'p-002'});
      expect(index.catalogIds, {'p-001', 'p-002', 'p-003'});
      expect(index.groupByShortId('000')?.groupId, 'p-001');
      expect(c.read(coldigomLouvoresCacheProvider), hasLength(1));
      expect(c.read(coldigomInMemoryCatalogProvider), hasLength(3));
      final state = c.read(coldigomCatalogSyncProvider);
      expect(state.lastResult, isA<ColdigomCatalogSyncInMemory>());
      expect(state.isSyncing, isFalse);
      expect(state.count, 3);
      expect(state.lastSyncedAt, isNotNull);
      expect(ColdigomCatalogSyncMetadataStore(prefs).readEtag(), isNull);
      expect(remote.calls, 1);
    },
  );

  test(
    'sem Isar: requestSyncIfStale ignora o syncedAt das prefs e baixa o dump',
    () async {
      // Prefs de uma sessão anterior com Isar: «sincronizado agora mesmo».
      await ColdigomCatalogSyncMetadataStore(prefs)
          .markReplaced(etag: '"v1"', count: 3, at: DateTime.now().toUtc());
      final remote = _ScriptedRemote(
        () async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
      );
      final c = container(remote: remote, isarAvailable: false);

      // Montar o notifier agenda o `requestSyncIfStale` do boot (um só
      // caminho, sem corrida com uma chamada explícita).
      c.read(coldigomCatalogSyncProvider);
      await pumpEventQueue();

      expect(remote.calls, 1);
      expect(remote.lastIfNoneMatch, isNull);
      expect(c.read(coldigomInMemoryCatalogProvider), hasLength(3));

      // O catálogo em memória acabou de chegar: pedir de novo não rebaixa.
      await c.read(coldigomCatalogSyncProvider.notifier).requestSyncIfStale();
      expect(remote.calls, 1);
    },
  );

  test(
    'Isar vazio com prefs dizendo que há catálogo: sincroniza mesmo assim',
    () async {
      // Ex.: a web apagou o IndexedDB mas manteve o localStorage.
      await ColdigomCatalogSyncMetadataStore(prefs)
          .markReplaced(etag: '"v1"', count: 3, at: DateTime.now().toUtc());
      final remote = _ScriptedRemote(
        () async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v2"'),
      );
      final c = container(remote: remote);

      c.read(coldigomCatalogSyncProvider);
      await pumpEventQueue();

      expect(remote.calls, 1);
      // Sem linhas no Isar o ETag guardado não vale (regra do use case).
      expect(remote.lastIfNoneMatch, isNull);
      expect(ColdigomCatalogLocalDatasource(isar).count(), 3);
    },
  );

  test('sync com dump novo re-hidrata; in-flight é deduplicado', () async {
    final remote = _ScriptedRemote(
      () async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
    );
    final c = container(remote: remote, online: false);
    expect(
      (await c.read(coldigomCatalogHydrationProvider.future)).isEmpty,
      isTrue,
    );

    final notifier = c.read(coldigomCatalogSyncProvider.notifier);
    final results = await Future.wait([notifier.sync(), notifier.sync()]);

    expect(results.whereType<ColdigomCatalogSyncReplaced>(), hasLength(2));
    expect(remote.calls, 1);
    final index = await c.read(coldigomCatalogHydrationProvider.future);
    expect(index.praiseIds, {'p-001', 'p-002'});
    expect(c.read(coldigomCatalogSyncProvider).count, 3);
    expect(c.read(coldigomCatalogSyncProvider).lastSyncedAt, isNotNull);
  });

  test(
    'coldigomCatalogRowProvider: linha ausente → sync grava → a linha aparece',
    () async {
      final remote = _ScriptedRemote(
        () async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
      );
      final c = container(remote: remote, online: false);
      await c.read(coldigomCatalogHydrationProvider.future);
      final row = c.listen(coldigomCatalogRowProvider('p-001'), (_, _) {});
      expect(row.read(), isNull);

      await c.read(coldigomCatalogSyncProvider.notifier).sync();
      await c.read(coldigomCatalogHydrationProvider.future);

      expect(row.read()?.praiseId, 'p-001');
      expect(row.read()?.lyrics, contains('Ainda há tempo'));
    },
  );

  test('coldigomCatalogRowProvider é descartado sem ouvintes', () async {
    await seed();
    final remote = _ScriptedRemote(
      () async => const ColdigomCatalogNotModified(),
    );
    final c = container(remote: remote, online: false);
    await c.read(coldigomCatalogHydrationProvider.future);
    final provider = coldigomCatalogRowProvider('p-001');
    final row = c.listen(provider, (_, _) {});
    expect(row.read()?.praiseId, 'p-001');

    row.close();
    await c.pump();

    expect(c.exists(provider), isFalse);
  });

  test('hidratação com erro → catalogIndexStatusProvider failed', () async {
    final c = ProviderContainer(
      overrides: [
        coldigomCatalogHydrationProvider.overrideWith(
          (ref) async => throw StateError('Isar ilegível'),
        ),
        coldigomCatalogSyncProvider.overrideWith(
          FakeColdigomCatalogSyncNotifier.new,
        ),
      ],
    );
    addTearDown(c.dispose);
    final status = c.listen(catalogIndexStatusProvider, (_, _) {});
    expect(status.read(), CatalogIndexStatus.loading);

    await expectLater(
      c.read(coldigomCatalogHydrationProvider.future),
      throwsStateError,
    );

    // O último sync foi bem-sucedido (noop), mas sem índice não há o que
    // mostrar: erro + «Tentar novamente», não um catálogo «pronto» vazio.
    expect(status.read(), CatalogIndexStatus.failed);
  });

  test('requestSyncIfStale respeita os 30 min e a rede', () async {
    final remote = _ScriptedRemote(
      () async => const ColdigomCatalogNotModified(),
    );
    await seed();
    await ColdigomCatalogSyncMetadataStore(prefs)
        .markReplaced(etag: '"v1"', count: 3, at: DateTime.now().toUtc());

    // Recente → nada.
    final fresh = container(remote: remote, online: true);
    await fresh.read(coldigomCatalogSyncProvider.notifier).requestSyncIfStale();
    // O pedido do boot (microtask de `build()`) também espera o Isar
    // assentar: deixá-lo terminar aqui, senão leria as prefs já envelhecidas
    // abaixo e este container (online) sincronizaria.
    await pumpEventQueue();
    expect(remote.calls, 0);

    // Velho mas offline → nada.
    await ColdigomCatalogSyncMetadataStore(
      prefs,
    ).markValidated(DateTime.now().toUtc().subtract(const Duration(hours: 2)));
    final offline = container(remote: remote, online: false);
    await offline
        .read(coldigomCatalogSyncProvider.notifier)
        .requestSyncIfStale();
    expect(remote.calls, 0);

    // Velho e online → sync.
    final stale = container(remote: remote, online: true);
    await stale.read(coldigomCatalogSyncProvider.notifier).requestSyncIfStale();
    expect(remote.calls, 1);
  });

  test(
    'sync espera o Isar abrir antes de tocar na rede/local (sem perder o ETag)',
    () async {
      await seed();
      await ColdigomCatalogSyncMetadataStore(prefs)
          .markReplaced(etag: '"v1"', count: 3, at: DateTime.now().toUtc());
      final remote = _ScriptedRemote(
        () async => const ColdigomCatalogNotModified(),
      );
      // Isar só assenta 50ms depois de aberto: se `sync()` ler
      // `coldigomCatalogLocalDatasourceProvider` antes disso, ele vê
      // `.unavailable()` (count 0), derruba o ETag guardado e pede o dump
      // inteiro — o que este teste prova que não acontece mais.
      final c = container(
        remote: remote,
        online: true,
        isarOpenDelay: const Duration(milliseconds: 50),
      );

      final result = await c.read(coldigomCatalogSyncProvider.notifier).sync();

      expect(result, isA<ColdigomCatalogSyncNoop>());
      expect(remote.calls, 1);
      expect(remote.lastIfNoneMatch, '"v1"');
      // 304: nem toca no Isar — o catálogo semeado continua intacto.
      expect(ColdigomCatalogLocalDatasource(isar).count(), 3);
    },
  );

  test(
    'praise só com YouTube fica fora do índice mas o link chega ao cache',
    () async {
      final onlyYoutube = ColdigomCatalogDto.fromJson(
        jsonDecode('''
        {
          "generatedAt": "2026-09-14T12:00:00.000Z",
          "kinds": [],
          "praises": [
            {
              "id": "p-yt",
              "number": "099",
              "name": "Só vídeo",
              "author": "",
              "rhythm": "",
              "tonality": "",
              "category": "",
              "tags": [],
              "materials": [
                {
                  "id": "yt-only",
                  "kind": null,
                  "type": "youtube",
                  "url": "https://www.youtube.com/watch?v=1Pks43ceAac"
                }
              ]
            }
          ]
        }
        ''') as Map<String, dynamic>,
      );
      await ColdigomCatalogLocalDatasource(isar).replaceAll([
        for (final p in onlyYoutube.praises)
          ColdigomPraiseCacheMapper.fromCatalogPraise(
            p,
            kindNames: onlyYoutube.kindNames,
          ),
      ]);
      final remote = _ScriptedRemote(
        () async => const ColdigomCatalogNotModified(),
      );
      final c = container(remote: remote, online: false);

      final index = await c.read(coldigomCatalogHydrationProvider.future);

      // Sem PDF/áudio/cifra/gesto/letra, o YouTube sozinho não sustenta um
      // grupo (mesma regra de `ColdigomCatalogSource.findGroupById`) — fica
      // fora do índice, mas o link ainda é útil no sheet de quem já abriu o
      // praise por outro caminho.
      expect(index.praiseIds, isNot(contains('p-yt')));
      expect(index.isEmpty, isTrue);
      // Mas está no Isar — e é por `catalogIds`, não `praiseIds`, que a
      // pesquisa remota sabe que já foi adotado (senão o chip «novo»
      // nunca sumiria pra este praise).
      expect(index.catalogIds, contains('p-yt'));
      expect(c.read(coldigomYoutubeCacheProvider)['p-yt'], hasLength(1));
    },
  );

  test(
    'sem catálogo e sem rede: requestSyncIfStale deixa a UI em erro',
    () async {
      final remote = _ScriptedRemote(
        () async => const ColdigomCatalogNotModified(),
      );
      final c = container(remote: remote, isarAvailable: false, online: false);

      await c.read(coldigomCatalogSyncProvider.notifier).requestSyncIfStale();
      await c.read(coldigomCatalogHydrationProvider.future);

      expect(
        c.read(coldigomCatalogSyncProvider).lastResult,
        isA<ColdigomCatalogSyncFailed>(),
      );
      expect(c.read(catalogIndexStatusProvider), CatalogIndexStatus.failed);
      expect(remote.calls, 0);
    },
  );

  test('sem Isar: uma falha não zera count/lastSyncedAt de um sync em memória anterior', () async {
    var callCount = 0;
    final remote = _ScriptedRemote(() async {
      callCount++;
      if (callCount == 1) {
        return ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"');
      }
      throw StateError('rede caiu');
    });
    final c = container(remote: remote, isarAvailable: false, online: false);
    expect(
      (await c.read(coldigomCatalogHydrationProvider.future)).isEmpty,
      isTrue,
    );

    final notifier = c.read(coldigomCatalogSyncProvider.notifier);
    final okResult = await notifier.sync();
    expect(okResult, isA<ColdigomCatalogSyncInMemory>());
    final afterOk = c.read(coldigomCatalogSyncProvider);
    expect(afterOk.count, 3);
    expect(afterOk.lastSyncedAt, isNotNull);

    final failResult = await notifier.sync();
    expect(failResult, isA<ColdigomCatalogSyncFailed>());
    final afterFail = c.read(coldigomCatalogSyncProvider);
    expect(afterFail.lastResult, isA<ColdigomCatalogSyncFailed>());
    expect(afterFail.isSyncing, isFalse);
    // Sem Isar não há prefs a reler: a falha não deve apagar o
    // count/lastSyncedAt do sync em memória anterior.
    expect(afterFail.count, afterOk.count);
    expect(afterFail.lastSyncedAt, afterOk.lastSyncedAt);
  });
}
