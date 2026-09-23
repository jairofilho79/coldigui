import 'dart:convert';
import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:coldigui/features/coldigom/domain/usecases/sync_coldigom_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remoto de roteiro: devolve o que o teste manda e regista o If-None-Match.
class _ScriptedRemote extends ColdigomRemoteDatasource {
  _ScriptedRemote(this._respond) : super(Dio());

  final Future<ColdigomCatalogFetchResult> Function(String? ifNoneMatch)
  _respond;
  final ifNoneMatches = <String?>[];

  @override
  Future<ColdigomCatalogFetchResult> fetchCatalog({String? ifNoneMatch}) {
    ifNoneMatches.add(ifNoneMatch);
    return _respond(ifNoneMatch);
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
  late ColdigomCatalogLocalDatasource local;
  late ColdigomCatalogSyncMetadataStore metadata;
  final fixedNow = DateTime.utc(2026, 9, 14, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    metadata = ColdigomCatalogSyncMetadataStore(
      await SharedPreferences.getInstance(),
    );
    tempDir = await Directory.systemTemp.createTemp('sync_coldigom_');
    isar = Isar.open(
      schemas: [ColdigomPraiseCacheSchema],
      directory: tempDir.path,
      name: 'sync_coldigom_${DateTime.now().microsecondsSinceEpoch}',
    );
    local = ColdigomCatalogLocalDatasource(isar);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  SyncColdigomCatalog usecase(_ScriptedRemote remote) => SyncColdigomCatalog(
    remote: remote,
    local: local,
    metadata: metadata,
    now: () => fixedNow,
  );

  test('200 → replaceAll, etag, syncedAt e count gravados', () async {
    final remote = _ScriptedRemote(
      (_) async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
    );

    final result = await usecase(remote).run();

    expect(result, isA<ColdigomCatalogSyncReplaced>());
    expect((result as ColdigomCatalogSyncReplaced).count, 3);
    expect(local.count(), 3);
    expect(metadata.readEtag(), '"v1"');
    expect(metadata.readSyncedAt(), fixedNow);
    expect(metadata.readCount(), 3);
    expect(remote.ifNoneMatches, [null]);
  });

  test(
    '304 → noop, manda o etag guardado, renova syncedAt sem tocar no Isar',
    () async {
      await metadata.markReplaced(
        etag: '"v1"',
        count: 3,
        at: DateTime.utc(2026, 1, 1),
      );
      await local.replaceAll([
        ColdigomPraiseCache()
          ..praiseId = 'antigo'
          ..number = ''
          ..name = ''
          ..author = ''
          ..rhythm = ''
          ..tonality = ''
          ..category = ''
          ..tags = const []
          ..lyrics = ''
          ..materialsJson = '[]'
          ..searchTokens = '',
      ]);
      final remote = _ScriptedRemote(
        (_) async => const ColdigomCatalogNotModified(),
      );

      final result = await usecase(remote).run();

      expect(result, isA<ColdigomCatalogSyncNoop>());
      expect(remote.ifNoneMatches, ['"v1"']);
      expect(local.findAllSync().single.praiseId, 'antigo');
      expect(metadata.readEtag(), '"v1"');
      expect(metadata.readSyncedAt(), fixedNow);
    },
  );

  test('falha de rede → failed com a causa, Isar e etag intactos', () async {
    await metadata.markReplaced(
      etag: '"v1"',
      count: 0,
      at: DateTime.utc(2026, 1, 1),
    );
    final remote = _ScriptedRemote(
      (_) async => throw DioException(
        requestOptions: RequestOptions(path: '/api/plpcg/catalog'),
        type: DioExceptionType.connectionError,
      ),
    );

    final result = await usecase(remote).run();

    expect(result, isA<ColdigomCatalogSyncFailed>());
    expect((result as ColdigomCatalogSyncFailed).cause, isA<DioException>());
    expect(local.count(), 0);
    expect(metadata.readEtag(), '"v1"');
    expect(metadata.readSyncedAt(), DateTime.utc(2026, 1, 1));
  });

  test(
    '200 com dump vazio → failed sem tocar no catálogo local nem no etag',
    () async {
      await metadata.markReplaced(
        etag: '"v1"',
        count: 3,
        at: DateTime.utc(2026, 1, 1),
      );
      await local.replaceAll([
        ColdigomPraiseCache()
          ..praiseId = 'antigo'
          ..number = ''
          ..name = ''
          ..author = ''
          ..rhythm = ''
          ..tonality = ''
          ..category = ''
          ..tags = const []
          ..lyrics = ''
          ..materialsJson = '[]'
          ..searchTokens = '',
      ]);
      final remote = _ScriptedRemote(
        (_) async => const ColdigomCatalogFresh(
          catalog: ColdigomCatalogDto(
            generatedAt: '',
            kindNames: {},
            praises: [],
          ),
          etag: '"v2"',
        ),
      );

      final result = await usecase(remote).run();

      expect(result, isA<ColdigomCatalogSyncFailed>());
      expect((result as ColdigomCatalogSyncFailed).cause, 'dump vazio');
      expect(local.count(), 1);
      expect(local.findAllSync().single.praiseId, 'antigo');
      expect(metadata.readEtag(), '"v1"');
      expect(metadata.readCount(), 3);
    },
  );

  test(
    'sem Isar → dump em memória: nada gravado, pedido sem If-None-Match',
    () async {
      await metadata.markReplaced(
        etag: '"v0"',
        count: 3,
        at: DateTime.utc(2026, 1, 1),
      );
      final remote = _ScriptedRemote(
        (_) async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
      );
      final degraded = SyncColdigomCatalog(
        remote: remote,
        local: const ColdigomCatalogLocalDatasource.unavailable(),
        metadata: metadata,
        now: () => fixedNow,
      );

      final result = await degraded.run();

      expect(result, isA<ColdigomCatalogSyncInMemory>());
      final inMemory = result as ColdigomCatalogSyncInMemory;
      expect(inMemory.count, 3);
      expect(inMemory.rows.map((r) => r.praiseId), ['p-001', 'p-002', 'p-003']);
      expect(inMemory.rows.first.shortId, '000');
      // O ETag guardado é de um Isar que não está aqui: pede o corpo inteiro.
      expect(remote.ifNoneMatches, [null]);
      // Nada de metadados: o próximo arranque sem Isar baixa de novo.
      expect(metadata.readEtag(), '"v0"');
      expect(metadata.readSyncedAt(), DateTime.utc(2026, 1, 1));
    },
  );

  test('sem Isar e dump vazio → failed (nunca um catálogo vazio)', () async {
    final remote = _ScriptedRemote(
      (_) async => const ColdigomCatalogFresh(
        catalog: ColdigomCatalogDto(
          generatedAt: '',
          kindNames: {},
          praises: [],
        ),
        etag: '"v2"',
      ),
    );
    final degraded = SyncColdigomCatalog(
      remote: remote,
      local: const ColdigomCatalogLocalDatasource.unavailable(),
      metadata: metadata,
      now: () => fixedNow,
    );

    final result = await degraded.run();

    expect(result, isA<ColdigomCatalogSyncFailed>());
    expect((result as ColdigomCatalogSyncFailed).cause, 'dump vazio');
  });
}
