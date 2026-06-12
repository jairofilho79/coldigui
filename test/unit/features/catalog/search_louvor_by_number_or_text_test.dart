import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/usecases/search_louvor_by_number_or_text.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({
  required String nome,
  required String numero,
  required String pdfId,
}) =>
    Louvor.fromManifest(
      nome: nome,
      numero: numero,
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '$numero.pdf',
      pdfId: pdfId,
    );

void main() {
  late SearchLouvorByNumberOrText search;
  late List<Louvor> catalog;

  setUp(() {
    search = const SearchLouvorByNumberOrText();
    catalog = [
      _louvor(nome: 'São João', numero: '123', pdfId: 'a'),
      _louvor(nome: 'Aleluia ao Senhor', numero: '456', pdfId: 'b'),
      _louvor(nome: 'Outro louvor', numero: '789', pdfId: 'c'),
      _louvor(nome: 'Buscar-me-eis', numero: '999', pdfId: 'd'),
    ];
  });

  test('query vazia retorna lista vazia', () {
    expect(search(catalog, ''), isEmpty);
    expect(search(catalog, '   '), isEmpty);
  });

  test('número exato retorna match prioritário', () {
    final result = search(catalog, '123');

    expect(result, hasLength(1));
    expect(result.first.numero, '123');
  });

  test('número exato vem antes de matches textuais', () {
    final extended = [
      ...catalog,
      _louvor(nome: 'Louvor 123 especial', numero: '999', pdfId: 'd'),
    ];

    final result = search(extended, '123');

    expect(result.first.numero, '123');
    expect(result, hasLength(2));
  });

  test('busca textual tolerante a acentos e stop words', () {
    final result = search(catalog, 'sao joao');

    expect(result, hasLength(1));
    expect(result.first.nome, 'São João');
  });

  test('sem match retorna lista vazia', () {
    expect(search(catalog, 'inexistente xyz'), isEmpty);
  });

  test('busca flexível com hífens, espaços ou texto compacto', () {
    for (final query in ['buscarmeeis', 'buscar me eis', 'buscar-me-eis']) {
      final result = search(catalog, query);
      expect(result, hasLength(1), reason: 'query: $query');
      expect(result.first.nome, 'Buscar-me-eis');
    }
  });
}
