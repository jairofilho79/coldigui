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
}
