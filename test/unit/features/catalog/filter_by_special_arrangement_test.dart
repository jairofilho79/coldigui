import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/usecases/filter_by_special_arrangement.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_classification.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({
  required String nome,
  required String classificacao,
  String pdfId = 'id',
}) =>
    Louvor.fromManifest(
      nome: nome,
      numero: '1',
      categoria: 'Partitura',
      classificacao: classificacao,
      pdf: '1.pdf',
      pdfId: pdfId,
    );

void main() {
  late FilterBySpecialArrangement filter;
  late List<Louvor> catalog;

  setUp(() {
    filter = const FilterBySpecialArrangement();
    catalog = [
      _louvor(
        nome: 'Padrão',
        classificacao: 'ColAdultos',
        pdfId: 'a',
      ),
      _louvor(
        nome: 'Especial',
        classificacao: 'ColAdultos (Especial)',
        pdfId: 'b',
      ),
      _louvor(
        nome: 'Outro',
        classificacao: 'ColJuvenil (Especial)',
        pdfId: 'c',
      ),
    ];
  });

  test('seleção vazia retorna todos', () {
    expect(
      filter(catalog, selectedSpecialArrangements: {}),
      hasLength(3),
    );
  });

  test('filtra por Padrão', () {
    final result = filter(
      catalog,
      selectedSpecialArrangements: {
        LouvorClassification.specialArrangementPadrao,
      },
    );

    expect(result, hasLength(1));
    expect(result.first.pdfId, 'a');
  });

  test('filtra por arranjo entre parênteses', () {
    final result = filter(
      catalog,
      selectedSpecialArrangements: {'Especial'},
    );

    expect(result, hasLength(2));
    expect(result.map((l) => l.pdfId), containsAll(['b', 'c']));
  });
}
