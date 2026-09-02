import 'package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_sync_metadata_store.dart';
import 'package:coldigui/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _louvor(String pdfId, {String nome = 'Louvor', String numero = '001'}) =>
    Louvor.fromManifest(
      nome: nome,
      numero: numero,
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '001.pdf',
      pdfId: pdfId,
    );

class _TestRemote extends CatalogRemoteDatasource {
  _TestRemote({
    this.louvores,
    this.error,
    this.checksumResult,
    this.notModified = false,
    this.manifestEtag,
  }) : super(Dio());

  final List<Louvor>? louvores;
  final Object? error;
  final ManifestChecksumResult? checksumResult;
  final bool notModified;
  final String? manifestEtag;

  var manifestCalls = 0;
  var checksumCalls = 0;
  String? lastManifestIfNoneMatch;
  String? lastChecksumIfNoneMatch;

  @override
  Future<ManifestChecksumResult> fetchChecksumConditional({
    String? ifNoneMatch,
  }) async {
    checksumCalls++;
    lastChecksumIfNoneMatch = ifNoneMatch;
    return checksumResult ??
        const ManifestChecksumResult(ManifestChecksumStatus.unavailable);
  }

  @override
  Future<ManifestFetchResult> fetchManifestConditional({
    String? ifNoneMatch,
  }) async {
    manifestCalls++;
    lastManifestIfNoneMatch = ifNoneMatch;
    if (error != null) throw error!;
    if (notModified) return const ManifestFetchResult.notModified();
    return ManifestFetchResult(
      louvores: louvores ?? const [],
      etag: manifestEtag,
    );
  }
}

class _TestLocal extends CatalogLocalDatasource {
  _TestLocal() : super(_FakeIsar());

  final List<Louvor> store = [];
  var saveCalls = 0;

  @override
  Future<void> saveLouvores(List<Louvor> louvores) async {
    saveCalls++;
    store
      ..clear()
      ..addAll(louvores);
  }

  @override
  Future<List<Louvor>> loadLouvores() async => List.of(store);
}

/// Isar não usado — métodos sobrescritos em [_TestLocal].
class _FakeIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CatalogRepositoryImpl _repo({
  required _TestRemote remote,
  required _TestLocal local,
  SharedPreferences? prefs,
}) {
  return CatalogRepositoryImpl(
    remote: remote,
    local: local,
    syncMetadata: CatalogSyncMetadataStore(prefs ?? _throwingPrefs()),
  );
}

SharedPreferences _throwingPrefs() {
  throw StateError('SharedPreferences not initialized — call setUp');
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadCachedLouvores retorna cache local sem rede', () async {
    final remote = _TestRemote(error: Exception('offline'));
    final local = _TestLocal()..store.add(_louvor('cached-only'));
    final prefs = await SharedPreferences.getInstance();

    final repo = _repo(remote: remote, local: local, prefs: prefs);

    final cached = await repo.loadCachedLouvores();

    expect(cached, hasLength(1));
    expect(cached.first.pdfId, 'cached-only');
  });

  test('sucesso remoto persiste e retorna louvores', () async {
    final remote = _TestRemote(louvores: [_louvor('remote-1')]);
    final local = _TestLocal();
    final prefs = await SharedPreferences.getInstance();

    final repo = _repo(remote: remote, local: local, prefs: prefs);

    final result = await repo.loadManifest();

    expect(result, hasLength(1));
    expect(result.first.pdfId, 'remote-1');
    expect(local.store, hasLength(1));
    expect(await repo.isCatalogStale(), isFalse);
  });

  test('falha remota usa cache local', () async {
    final remote = _TestRemote(error: Exception('offline'));
    final local = _TestLocal()..store.add(_louvor('cached-1'));
    final prefs = await SharedPreferences.getInstance();

    final repo = _repo(remote: remote, local: local, prefs: prefs);

    final result = await repo.loadManifest();

    expect(result, hasLength(1));
    expect(result.first.pdfId, 'cached-1');
    expect(await repo.isCatalogStale(), isTrue);
  });

  test('remoto vazio preserva cache existente', () async {
    final remote = _TestRemote(louvores: []);
    final local = _TestLocal()..store.add(_louvor('cached-1'));
    final prefs = await SharedPreferences.getInstance();

    final repo = _repo(remote: remote, local: local, prefs: prefs);

    final result = await repo.loadManifest();

    expect(result, hasLength(1));
    expect(result.first.pdfId, 'cached-1');
    expect(local.store.first.pdfId, 'cached-1');
  });

  test('falha remota sem cache propaga erro', () async {
    final remote = _TestRemote(error: Exception('offline'));
    final local = _TestLocal();
    final prefs = await SharedPreferences.getInstance();

    final repo = _repo(remote: remote, local: local, prefs: prefs);

    expect(repo.loadManifest(), throwsA(isA<Exception>()));
  });

  test('forceRefreshManifest sucesso persiste e retorna louvores', () async {
    final remote = _TestRemote(louvores: [_louvor('remote-refresh')]);
    final local = _TestLocal();
    final prefs = await SharedPreferences.getInstance();

    final repo = _repo(remote: remote, local: local, prefs: prefs);

    final result = await repo.forceRefreshManifest();

    expect(result, hasLength(1));
    expect(result.first.pdfId, 'remote-refresh');
    expect(local.store, hasLength(1));
    expect(local.store.first.pdfId, 'remote-refresh');
    expect(await repo.isCatalogStale(), isFalse);
  });

  test('forceRefreshManifest falha remota sem fallback ao cache', () async {
    final remote = _TestRemote(error: Exception('offline'));
    final local = _TestLocal()..store.add(_louvor('cached-1'));
    final prefs = await SharedPreferences.getInstance();

    final repo = _repo(remote: remote, local: local, prefs: prefs);

    await expectLater(repo.forceRefreshManifest(), throwsA(isA<Exception>()));
    expect(local.store.first.pdfId, 'cached-1');
  });

  test('forceRefreshManifest remoto vazio falha sem fallback', () async {
    final remote = _TestRemote(louvores: []);
    final local = _TestLocal()..store.add(_louvor('cached-1'));
    final prefs = await SharedPreferences.getInstance();

    final repo = _repo(remote: remote, local: local, prefs: prefs);

    await expectLater(repo.forceRefreshManifest(), throwsA(isA<StateError>()));
    expect(local.store.first.pdfId, 'cached-1');
  });

  test('isCatalogStale true quando sync antigo', () async {
    final remote = _TestRemote(error: Exception('offline'));
    final local = _TestLocal()..store.add(_louvor('cached-1'));
    final staleDate = DateTime.now()
        .subtract(const Duration(days: 8))
        .toIso8601String();
    SharedPreferences.setMockInitialValues({'catalogLastSyncAt': staleDate});
    final prefs = await SharedPreferences.getInstance();

    final repo = _repo(remote: remote, local: local, prefs: prefs);

    await repo.loadManifest();

    expect(await repo.isCatalogStale(), isTrue);
  });

  test('isCatalogStale false após sync recente em prefs', () async {
    final remote = _TestRemote(error: Exception('offline'));
    final local = _TestLocal()..store.add(_louvor('cached-1'));
    final recentDate = DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String();
    SharedPreferences.setMockInitialValues({'catalogLastSyncAt': recentDate});
    final prefs = await SharedPreferences.getInstance();

    final repo = _repo(remote: remote, local: local, prefs: prefs);

    await repo.loadManifest();

    expect(await repo.isCatalogStale(), isFalse);
  });

  group('syncManifest — gate por checksum (A1)', () {
    test(
      '(a) checksum igual não baixa o manifest nem reescreve o cache',
      () async {
        final remote = _TestRemote(
          louvores: [_louvor('remote-1')],
          checksumResult: const ManifestChecksumResult(
            ManifestChecksumStatus.unchanged,
          ),
        );
        final local = _TestLocal()..store.add(_louvor('cached-1'));
        final prefs = await SharedPreferences.getInstance();

        final repo = _repo(remote: remote, local: local, prefs: prefs);
        final cached = await repo.loadCachedLouvores();

        final outcome = await repo.syncManifest(
          cached: cached,
          knownChecksum: 'abc123',
        );

        expect(remote.checksumCalls, 1);
        expect(remote.lastChecksumIfNoneMatch, 'abc123');
        expect(
          remote.manifestCalls,
          0,
          reason: 'manifest não deve ser baixado',
        );
        expect(local.saveCalls, 0, reason: 'Isar não deve ser reescrito');
        expect(outcome.cacheReplaced, isFalse);
        expect(outcome.louvores, same(cached));
        expect(outcome.checksum, isNull);
        expect(
          await repo.isCatalogStale(),
          isFalse,
          reason: 'checksum confirmado conta como sync bem-sucedido',
        );
      },
    );

    test('(b) checksum diferente baixa o manifest e grava no cache', () async {
      final remote = _TestRemote(
        louvores: [_louvor('remote-1')],
        checksumResult: const ManifestChecksumResult(
          ManifestChecksumStatus.changed,
          checksum: 'novo',
        ),
      );
      final local = _TestLocal()..store.add(_louvor('cached-1'));
      final prefs = await SharedPreferences.getInstance();

      final repo = _repo(remote: remote, local: local, prefs: prefs);
      final cached = await repo.loadCachedLouvores();

      final outcome = await repo.syncManifest(
        cached: cached,
        knownChecksum: 'antigo',
      );

      expect(remote.manifestCalls, 1);
      expect(remote.lastManifestIfNoneMatch, 'antigo');
      expect(local.saveCalls, 1);
      expect(local.store.single.pdfId, 'remote-1');
      expect(outcome.cacheReplaced, isTrue);
      expect(outcome.louvores.single.pdfId, 'remote-1');
      expect(outcome.checksum, 'novo');
    });

    test('(c) manifest idêntico ao cache não chama cacheManifest', () async {
      final remote = _TestRemote(
        louvores: [
          _louvor('same-1'),
          _louvor('same-2', numero: '002'),
        ],
        checksumResult: const ManifestChecksumResult(
          ManifestChecksumStatus.changed,
          checksum: 'novo',
        ),
      );
      final local = _TestLocal()
        ..store.addAll([_louvor('same-1'), _louvor('same-2', numero: '002')]);
      final prefs = await SharedPreferences.getInstance();

      final repo = _repo(remote: remote, local: local, prefs: prefs);
      final cached = await repo.loadCachedLouvores();

      final outcome = await repo.syncManifest(
        cached: cached,
        knownChecksum: 'antigo',
      );

      expect(remote.manifestCalls, 1);
      expect(local.saveCalls, 0, reason: 'lista idêntica → sem clear + putAll');
      expect(outcome.cacheReplaced, isFalse);
      expect(outcome.louvores, same(cached));
      expect(outcome.checksum, 'novo');
      expect(await repo.isCatalogStale(), isFalse);
    });

    test('(d) 304 no manifest não grava nada', () async {
      final remote = _TestRemote(
        notModified: true,
        checksumResult: const ManifestChecksumResult(
          ManifestChecksumStatus.unavailable,
        ),
      );
      final local = _TestLocal()..store.add(_louvor('cached-1'));
      final prefs = await SharedPreferences.getInstance();

      final repo = _repo(remote: remote, local: local, prefs: prefs);
      final cached = await repo.loadCachedLouvores();

      final outcome = await repo.syncManifest(
        cached: cached,
        knownChecksum: 'abc123',
      );

      expect(remote.manifestCalls, 1);
      expect(remote.lastManifestIfNoneMatch, 'abc123');
      expect(local.saveCalls, 0);
      expect(outcome.cacheReplaced, isFalse);
      expect(outcome.louvores, same(cached));
      expect(await repo.isCatalogStale(), isFalse);
    });

    test('checksum 503 (unavailable) ainda baixa o manifest', () async {
      final remote = _TestRemote(
        louvores: [_louvor('remote-1')],
        checksumResult: const ManifestChecksumResult(
          ManifestChecksumStatus.unavailable,
        ),
      );
      final local = _TestLocal()..store.add(_louvor('cached-1'));
      final prefs = await SharedPreferences.getInstance();

      final repo = _repo(remote: remote, local: local, prefs: prefs);
      final cached = await repo.loadCachedLouvores();

      final outcome = await repo.syncManifest(
        cached: cached,
        knownChecksum: 'abc123',
      );

      expect(remote.manifestCalls, 1);
      expect(local.saveCalls, 1);
      expect(outcome.cacheReplaced, isTrue);
    });

    test(
      'sem checksum salvo pula o endpoint e usa o ETag do manifest',
      () async {
        final remote = _TestRemote(
          louvores: [_louvor('remote-1')],
          manifestEtag: 'etag-do-manifest',
        );
        final local = _TestLocal()..store.add(_louvor('cached-1'));
        final prefs = await SharedPreferences.getInstance();

        final repo = _repo(remote: remote, local: local, prefs: prefs);
        final cached = await repo.loadCachedLouvores();

        final outcome = await repo.syncManifest(cached: cached);

        expect(remote.checksumCalls, 0);
        expect(remote.manifestCalls, 1);
        expect(remote.lastManifestIfNoneMatch, isNull);
        expect(outcome.checksum, 'etag-do-manifest');
      },
    );

    test('falha de rede mantém o cache em memória sem gravar', () async {
      final remote = _TestRemote(error: Exception('offline'));
      final local = _TestLocal()..store.add(_louvor('cached-1'));
      final prefs = await SharedPreferences.getInstance();

      final repo = _repo(remote: remote, local: local, prefs: prefs);
      final cached = await repo.loadCachedLouvores();

      final outcome = await repo.syncManifest(cached: cached);

      expect(local.saveCalls, 0);
      expect(outcome.cacheReplaced, isFalse);
      expect(outcome.louvores, same(cached));
      expect(outcome.checksum, isNull);
    });

    test('cache vazio ignora o checksum e baixa o manifest', () async {
      final remote = _TestRemote(
        louvores: [_louvor('remote-1')],
        checksumResult: const ManifestChecksumResult(
          ManifestChecksumStatus.unchanged,
        ),
      );
      final local = _TestLocal();
      final prefs = await SharedPreferences.getInstance();

      final repo = _repo(remote: remote, local: local, prefs: prefs);

      final outcome = await repo.syncManifest(
        cached: const [],
        knownChecksum: 'abc123',
      );

      expect(remote.checksumCalls, 0);
      expect(remote.manifestCalls, 1);
      expect(local.saveCalls, 1);
      expect(outcome.cacheReplaced, isTrue);
    });
  });
}
