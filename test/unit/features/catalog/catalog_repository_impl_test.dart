import 'package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:coldigui/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

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

void main() {
  test('sucesso remoto persiste e retorna louvores', () async {
    final remote = _TestRemote(louvores: [_louvor('remote-1')]);
    final local = _TestLocal();

    final repo = CatalogRepositoryImpl(remote: remote, local: local);

    final result = await repo.loadManifest();

    expect(result, hasLength(1));
    expect(result.first.pdfId, 'remote-1');
    expect(local.store, hasLength(1));
  });

  test('falha remota usa cache local', () async {
    final remote = _TestRemote(error: Exception('offline'));
    final local = _TestLocal()..store.add(_louvor('cached-1'));

    final repo = CatalogRepositoryImpl(remote: remote, local: local);

    final result = await repo.loadManifest();

    expect(result, hasLength(1));
    expect(result.first.pdfId, 'cached-1');
  });

  test('remoto vazio preserva cache existente', () async {
    final remote = _TestRemote(louvores: []);
    final local = _TestLocal()..store.add(_louvor('cached-1'));

    final repo = CatalogRepositoryImpl(remote: remote, local: local);

    final result = await repo.loadManifest();

    expect(result, hasLength(1));
    expect(result.first.pdfId, 'cached-1');
    expect(local.store.first.pdfId, 'cached-1');
  });

  test('falha remota sem cache propaga erro', () async {
    final remote = _TestRemote(error: Exception('offline'));
    final local = _TestLocal();

    final repo = CatalogRepositoryImpl(remote: remote, local: local);

    expect(repo.loadManifest(), throwsA(isA<Exception>()));
  });

  test('forceRefreshManifest sucesso persiste e retorna louvores', () async {
    final remote = _TestRemote(louvores: [_louvor('remote-refresh')]);
    final local = _TestLocal();

    final repo = CatalogRepositoryImpl(remote: remote, local: local);

    final result = await repo.forceRefreshManifest();

    expect(result, hasLength(1));
    expect(result.first.pdfId, 'remote-refresh');
    expect(local.store, hasLength(1));
    expect(local.store.first.pdfId, 'remote-refresh');
  });

  test('forceRefreshManifest falha remota sem fallback ao cache', () async {
    final remote = _TestRemote(error: Exception('offline'));
    final local = _TestLocal()..store.add(_louvor('cached-1'));

    final repo = CatalogRepositoryImpl(remote: remote, local: local);

    await expectLater(
      repo.forceRefreshManifest(),
      throwsA(isA<Exception>()),
    );
    expect(local.store.first.pdfId, 'cached-1');
  });

  test('forceRefreshManifest remoto vazio falha sem fallback', () async {
    final remote = _TestRemote(louvores: []);
    final local = _TestLocal()..store.add(_louvor('cached-1'));

    final repo = CatalogRepositoryImpl(remote: remote, local: local);

    await expectLater(
      repo.forceRefreshManifest(),
      throwsA(isA<StateError>()),
    );
    expect(local.store.first.pdfId, 'cached-1');
  });
}
