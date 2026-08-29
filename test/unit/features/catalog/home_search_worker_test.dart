import 'dart:isolate';

import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runHomeSearchPipeline no isolate retorna grupos filtrados', () async {
    final catalog = [
      Louvor.fromManifest(
        nome: 'Aleluia',
        numero: '001',
        categoria: 'Partitura',
        classificacao: 'ColAdultos',
        pdf: '001.pdf',
        pdfId: 'id-001',
      ),
    ];
    final input = HomeSearchPipelineInput(
      catalog: catalog,
      query: '001',
      selectedMaterials: CatalogMaterials.defaultSelected,
      selectedArranjos: {},
    );

    final result = await Isolate.run(() => runHomeSearchPipeline(input));

    expect(result, hasLength(1));
    expect(result.first.nome, 'Aleluia');
  });

  test('runHomeSearchPipeline preserva ranking: título exato no topo', () {
    final catalog = [
      Louvor.fromManifest(
        nome: 'Senhor Deus',
        numero: '001',
        categoria: 'Partitura',
        classificacao: 'ColAdultos',
        pdf: '001.pdf',
        pdfId: 'partial',
      ),
      Louvor.fromManifest(
        nome: 'A Ti Senhor',
        numero: '500',
        categoria: 'Partitura',
        classificacao: 'ColAdultos',
        pdf: '500.pdf',
        pdfId: 'exact',
      ),
    ];
    final input = HomeSearchPipelineInput(
      catalog: catalog,
      query: 'A Ti Senhor',
      selectedMaterials: CatalogMaterials.defaultSelected,
      selectedArranjos: {},
    );

    final result = runHomeSearchPipeline(input);

    expect(result.first.nome, 'A Ti Senhor');
  });
}
