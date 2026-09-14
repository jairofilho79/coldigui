import 'dart:convert';
import 'dart:io';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/network/device_connectivity.dart';
import 'package:coldigui/core/providers/device_connectivity_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
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
  @override
  Future<ColdigomCatalogFetchResult> fetchCatalog({String? ifNoneMatch}) {
    calls++;
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
  }) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarInitializerProvider.overrideWith(
          (ref) async => isarAvailable ? isar : throw StateError('sem isar'),
        ),
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
    // fica fora do índice — mas continua no Isar (`count` = 3).
    expect(index.praiseIds, {'p-001', 'p-002'});
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
    expect(remote.calls, 0);
  });

  test('sem Isar: índice vazio e sync falha sem gravar', () async {
    final remote = _ScriptedRemote(
      () async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
    );
    final c = container(remote: remote, isarAvailable: false);

    final index = await c.read(coldigomCatalogHydrationProvider.future);
    final result = await c.read(coldigomCatalogSyncProvider.notifier).sync();

    expect(index.isEmpty, isTrue);
    expect(result, isA<ColdigomCatalogSyncFailed>());
  });

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
}
