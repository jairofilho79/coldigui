import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:coldigui/features/catalog/domain/usecases/force_refresh_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository(this._louvores);

  final List<Louvor> _louvores;
  var forceRefreshManifestCalls = 0;

  @override
  Future<List<Louvor>> loadCachedLouvores() async => _louvores;

  @override
  Future<List<Louvor>> loadManifest() async => _louvores;

  @override
  Future<List<Louvor>> forceRefreshManifest() async {
    forceRefreshManifestCalls++;
    return _louvores;
  }

  @override
  Future<void> cacheManifest(List<Louvor> louvores) async {}

  @override
  Future<String?> fetchManifestChecksum() async => null;

  @override
  Future<bool> isCatalogStale() async => false;
}

void main() {
  test('ForceRefreshCatalog delega ao repository', () async {
    final louvor = Louvor.fromManifest(
      nome: 'Aleluia',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '001.pdf',
      pdfId: 'abc',
    );
    final repository = _FakeCatalogRepository([louvor]);
    final useCase = ForceRefreshCatalog(repository);

    final result = await useCase();

    expect(repository.forceRefreshManifestCalls, 1);
    expect(result, [louvor]);
  });
}
