import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/usecases/filter_by_material_and_arranjo.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({
  required String nome,
  required String categoria,
  required String classificacao,
  String numero = '1',
  String pdfId = 'id',
}) =>
    Louvor.fromManifest(
      nome: nome,
      numero: numero,
      categoria: categoria,
      classificacao: classificacao,
      pdf: '$numero.pdf',
      pdfId: pdfId,
    );

void main() {
  late FilterByMaterialAndArranjo filter;
  late List<Louvor> catalog;

  setUp(() {
    filter = const FilterByMaterialAndArranjo();
    catalog = [
      _louvor(
        nome: 'Partitura A',
        categoria: CatalogMaterials.partitura,
        classificacao: 'ColAdultos',
        pdfId: 'a',
      ),
      _louvor(
        nome: 'Cifra I',
        categoria: CatalogMaterials.cifraNivelI,
        classificacao: 'ColAdultos',
        pdfId: 'b',
      ),
      _louvor(
        nome: 'Cifra II',
        categoria: CatalogMaterials.cifraNivelII,
        classificacao: 'ColJuvenil',
        pdfId: 'c',
      ),
      _louvor(
        nome: 'Gestos',
        categoria: CatalogMaterials.gestosEmGravura,
        classificacao: 'ColAdultos (Especial)',
        pdfId: 'd',
      ),
    ];
  });

  test('sem materiais selecionados retorna vazio', () {
    expect(
      filter(catalog, selectedMaterials: {}, selectedArranjos: {}),
      isEmpty,
    );
  });

  test('todos os materiais sem filtro de arranjo retorna catálogo inteiro', () {
    final result = filter(
      catalog,
      selectedMaterials: CatalogMaterials.defaultSelected,
      selectedArranjos: {},
    );

    expect(result, hasLength(4));
  });

  test('Cifra expande para nível I e II', () {
    final result = filter(
      catalog,
      selectedMaterials: {CatalogMaterials.cifra},
      selectedArranjos: {},
    );

    expect(result, hasLength(2));
    expect(result.map((l) => l.pdfId), containsAll(['b', 'c']));
  });

  test('filtra por arranjo base ignorando parênteses', () {
    final result = filter(
      catalog,
      selectedMaterials: CatalogMaterials.defaultSelected,
      selectedArranjos: {'ColAdultos'},
    );

    expect(result, hasLength(3));
    expect(result.map((l) => l.pdfId), containsAll(['a', 'b', 'd']));
  });

  test('material e arranjo combinados', () {
    final result = filter(
      catalog,
      selectedMaterials: {CatalogMaterials.partitura},
      selectedArranjos: {'ColJuvenil'},
    );

    expect(result, isEmpty);
  });
}
