import '../../../support/fakes/fake_catalog_repository.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/usecases/load_louvores_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LoadLouvoresManifest delega ao repository', () async {
    final louvor = Louvor.fromManifest(
      nome: 'Aleluia',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '001.pdf',
      pdfId: 'abc',
    );
    final repository = FakeCatalogRepository(cached: [louvor]);
    final useCase = LoadLouvoresManifest(repository);

    final result = await useCase();

    expect(repository.loadManifestCalls, 1);
    expect(result, [louvor]);
  });
}
