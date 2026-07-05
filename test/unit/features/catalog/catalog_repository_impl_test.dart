import 'package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_sync_metadata_store.dart';
import 'package:coldigui/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _louvor(String pdfId) => Louvor.fromManifest(
  nome: 'Louvor',
  numero: '001',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: '001.pdf',
  pdfId: pdfId,
);

class _TestRemote extends CatalogRemoteDatasource {
  _TestRemote({this.louvores, this.error}) : super(Dio());

  final List<Louvor>? louvores;
  final Object? error;

  @override
  Future<List<Louvor>> fetchManifest() async {
    if (error != null) throw error!;
    return louvores ?? [];
  }
}

class _TestLocal extends CatalogLocalDatasource {
  _TestLocal() : super(_FakeIsar());

  final List<Louvor> store = [];

  @override
  Future<void> saveLouvores(List<Louvor> louvores) async {
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
}
