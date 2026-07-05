import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:coldigui/features/catalog/domain/repositories/manifest_checksum_reader.dart';
import 'package:coldigui/features/catalog/domain/usecases/poll_manifest_checksum.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository({this.checksum, this.louvores = const []});

  final String? checksum;
  final List<Louvor> louvores;
  Object? forceRefreshError;

  var fetchChecksumCalls = 0;
  var forceRefreshCalls = 0;

  @override
  Future<List<Louvor>> loadCachedLouvores() async => louvores;

  @override
  Future<List<Louvor>> loadManifest() async => louvores;

  @override
  Future<List<Louvor>> forceRefreshManifest() async {
    forceRefreshCalls++;
    if (forceRefreshError != null) throw forceRefreshError!;
    return louvores;
  }

  @override
  Future<void> cacheManifest(List<Louvor> louvores) async {}

  @override
  Future<String?> fetchManifestChecksum() async {
    fetchChecksumCalls++;
    return checksum;
  }

  @override
  Future<bool> isCatalogStale() async => false;
}

class _FakeChecksumStore implements ManifestChecksumReader {
  String? stored;

  var saveCalls = 0;

  @override
  Future<String?> getLastKnownChecksum() async => stored;

  @override
  Future<void> saveChecksum(String checksum) async {
    saveCalls++;
    stored = checksum;
  }
}

Louvor _louvor() => Louvor.fromManifest(
  nome: 'Aleluia',
  numero: '001',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: '001.pdf',
  pdfId: 'abc',
);

void main() {
  test('checksum igual não dispara sync', () async {
    const checksum = 'abc123';
    final repository = _FakeCatalogRepository(checksum: checksum);
    final store = _FakeChecksumStore()..stored = checksum;
    final useCase = PollManifestChecksum(repository, store);

    final synced = await useCase();

    expect(synced, isFalse);
    expect(repository.fetchChecksumCalls, 1);
    expect(repository.forceRefreshCalls, 0);
    expect(store.saveCalls, 0);
  });

  test('checksum diferente dispara sync e persiste novo checksum', () async {
    final repository = _FakeCatalogRepository(
      checksum: 'remote-new',
      louvores: [_louvor()],
    );
    final store = _FakeChecksumStore()..stored = 'local-old';
    final useCase = PollManifestChecksum(repository, store);

    final synced = await useCase();

    expect(synced, isTrue);
    expect(repository.fetchChecksumCalls, 1);
    expect(repository.forceRefreshCalls, 1);
    expect(store.saveCalls, 1);
    expect(store.stored, 'remote-new');
  });

  test('falha de rede (checksum null) não dispara sync', () async {
    final repository = _FakeCatalogRepository(checksum: null);
    final store = _FakeChecksumStore()..stored = 'local-old';
    final useCase = PollManifestChecksum(repository, store);

    final synced = await useCase();

    expect(synced, isFalse);
    expect(repository.fetchChecksumCalls, 1);
    expect(repository.forceRefreshCalls, 0);
    expect(store.saveCalls, 0);
    expect(store.stored, 'local-old');
  });
}
