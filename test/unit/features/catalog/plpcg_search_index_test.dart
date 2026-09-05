import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/search/plpcg_search_index.dart';
import 'package:coldigui/features/catalog/domain/usecases/search_louvor_by_number_or_text.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({
  required String nome,
  required String numero,
  required String pdfId,
  String categoria = 'Partitura',
  String classificacao = 'ColAdultos',
}) => Louvor.fromManifest(
  nome: nome,
  numero: numero,
  categoria: categoria,
  classificacao: classificacao,
  pdf: '$numero.pdf',
  pdfId: pdfId,
);

CatalogQuery _query(
  String text, {
  Set<String>? materiais,
  Set<String> arranjos = const {},
}) => CatalogQuery(
  text: text,
  filters: CatalogFilterState(
    selectedMaterials: materiais ?? CatalogMaterials.defaultSelected,
    selectedArranjos: arranjos,
  ),
);

void main() {
  group('PlpcgSearchIndex', () {
    test('build normaliza o numero uma vez, alinhado por índice', () {
      final catalog = [
        _louvor(nome: 'Aleluia', numero: '1', pdfId: 'a'),
        _louvor(nome: 'Comigo habita', numero: '692', pdfId: 'b'),
        _louvor(nome: 'Especial', numero: 'PES-609', pdfId: 'c'),
      ];

      final index = PlpcgSearchIndex.build(catalog);

      expect(index.louvores, hasLength(3));
      expect(index.numeroNorm, ['001', '692', 'PES-609']);
      expect(index.louvores[1], same(catalog[1]));
    });

    test('empty é um índice const sem louvores', () {
      expect(PlpcgSearchIndex.empty.louvores, isEmpty);
      expect(PlpcgSearchIndex.empty.numeroNorm, isEmpty);
      expect(
        runPlpcgSearchPipeline(PlpcgSearchIndex.empty, _query('aleluia')),
        isEmpty,
      );
    });
  });

  group('SearchLouvorByNumberOrText.callIndexed', () {
    test('reproduz o ranking de call sobre o mesmo catálogo', () {
      final catalog = [
        _louvor(nome: 'Senhor Deus', numero: '001', pdfId: 'partial'),
        _louvor(nome: 'A Ti Senhor', numero: '500', pdfId: 'exact'),
        _louvor(nome: 'Outro', numero: '017', pdfId: 'numero'),
      ];
      const usecase = SearchLouvorByNumberOrText();
      final index = PlpcgSearchIndex.build(catalog);

      for (final query in ['A Ti Senhor', '17', 'senhor', '', 'nada disso']) {
        expect(
          usecase.callIndexed(index, query).map((l) => l.pdfId).toList(),
          usecase(catalog, query).map((l) => l.pdfId).toList(),
          reason: 'query "$query"',
        );
      }
    });

    test('acha por número normalizado sem normalizar item a item', () {
      final catalog = [_louvor(nome: 'Aleluia', numero: '001', pdfId: 'a')];
      final index = PlpcgSearchIndex.build(catalog);

      final result = const SearchLouvorByNumberOrText().callIndexed(index, '1');

      expect(result.single.pdfId, 'a');
    });
  });

  group('runPlpcgSearchPipeline', () {
    test('ranking: número → título exato → título parcial', () {
      final catalog = [
        _louvor(nome: 'Senhor Deus', numero: '001', pdfId: 'partial'),
        _louvor(nome: 'A Ti Senhor', numero: '500', pdfId: 'exact'),
      ];
      final index = PlpcgSearchIndex.build(catalog);

      final result = runPlpcgSearchPipeline(index, _query('A Ti Senhor'));

      expect(result.first.nome, 'A Ti Senhor');
    });

    test('busca por número devolve o grupo do louvor', () {
      final catalog = [
        _louvor(nome: 'Aleluia', numero: '001', pdfId: 'id-001'),
      ];
      final index = PlpcgSearchIndex.build(catalog);

      final result = runPlpcgSearchPipeline(index, _query('001'));

      expect(result, hasLength(1));
      expect(result.first.nome, 'Aleluia');
    });

    test('aplica o filtro de material da query', () {
      final catalog = [
        _louvor(nome: 'Aleluia', numero: '001', pdfId: 'partitura'),
        _louvor(
          nome: 'Aleluia',
          numero: '001',
          pdfId: 'cifra',
          categoria: CatalogMaterials.cifraNivelI,
        ),
      ];
      final index = PlpcgSearchIndex.build(catalog);

      final soCifra = runPlpcgSearchPipeline(
        index,
        _query('aleluia', materiais: {CatalogMaterials.cifra}),
      );

      expect(soCifra, hasLength(1));
      expect(soCifra.first.totalMaterials, 1);
    });

    test('query vazia devolve vazio sem varrer o índice', () {
      final catalog = [_louvor(nome: 'Aleluia', numero: '001', pdfId: 'a')];
      final index = PlpcgSearchIndex.build(catalog);

      expect(runPlpcgSearchPipeline(index, _query('   ')), isEmpty);
    });
  });
}
