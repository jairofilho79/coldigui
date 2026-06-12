import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_classification.dart';
import 'package:coldigui/features/library/domain/usecases/browse_library.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({
  required String nome,
  required String categoria,
  required String classificacao,
  String pdfId = 'id',
}) =>
    Louvor.fromManifest(
      nome: nome,
      numero: '1',
      categoria: categoria,
      classificacao: classificacao,
      pdf: '1.pdf',
      pdfId: pdfId,
    );

void main() {
  late BrowseLibrary browse;
  late List<Louvor> catalog;

  setUp(() {
    browse = const BrowseLibrary();
    catalog = [
      _louvor(
        nome: 'Partitura',
        categoria: CatalogMaterials.partitura,
        classificacao: 'ColAdultos',
        pdfId: 'a',
      ),
      _louvor(
        nome: 'Cifra',
        categoria: CatalogMaterials.cifraNivelI,
        classificacao: 'ColJuvenil',
        pdfId: 'b',
      ),
      _louvor(
        nome: 'Especial',
        categoria: CatalogMaterials.partitura,
        classificacao: 'ColAdultos (Especial)',
        pdfId: 'c',
      ),
    ];
  });

  test('sem busca retorna catálogo filtrado por material', () {
    final result = browse(
      catalog,
      selectedMaterials: {CatalogMaterials.partitura},
      selectedArranjos: {},
      selectedSpecialArrangements: {},
    );

    expect(result, hasLength(2));
    expect(result.map((l) => l.pdfId), containsAll(['a', 'c']));
  });

  test('combina material, arranjo base e especial', () {
    final result = browse(
      catalog,
      selectedMaterials: CatalogMaterials.defaultSelected,
      selectedArranjos: {'ColAdultos'},
      selectedSpecialArrangements: {'Especial'},
    );

    expect(result, hasLength(1));
    expect(result.first.pdfId, 'c');
  });

  test('filtra por arranjo especial Padrão', () {
    final result = browse(
      catalog,
      selectedMaterials: CatalogMaterials.defaultSelected,
      selectedArranjos: {},
      selectedSpecialArrangements: {
        LouvorClassification.specialArrangementPadrao,
      },
    );

    expect(result, hasLength(2));
    expect(result.map((l) => l.pdfId), containsAll(['a', 'b']));
  });
}
