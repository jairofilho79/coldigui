import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/search/plpcg_search_index.dart';
import 'package:coldigui/features/catalog/domain/usecases/search_louvor_by_number_or_text.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({
  required String nome,
  required String numero,
  required String pdfId,
}) => Louvor.fromManifest(
  nome: nome,
  numero: numero,
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: '$numero.pdf',
  pdfId: pdfId,
);

void main() {
  // `call()` não indexado foi removido (A10/E5): só sobrava sem chamador em
  // `lib/`. A cobertura abaixo continua valendo para `callIndexed`, a única
  // variante que resta (usada pela Home via `PlpcgSearchIndex`).
  late List<Louvor> Function(List<Louvor> catalog, String query) search;
  late List<Louvor> catalog;

  setUp(() {
    const usecase = SearchLouvorByNumberOrText();
    search = (catalog, query) =>
        usecase.callIndexed(PlpcgSearchIndex.build(catalog), query);
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

  test('busca por número aceita zeros à esquerda', () {
    final extended = [
      ...catalog,
      _louvor(nome: 'Clamo a ti', numero: '003', pdfId: 'e'),
    ];

    expect(search(extended, '3'), hasLength(1));
    expect(search(extended, '3').first.numero, '003');
    expect(search(extended, '003'), hasLength(1));
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

  test('busca por prefixo de palavra na query', () {
    final extended = [
      ...catalog,
      _louvor(nome: 'Alto Preço', numero: '100', pdfId: 'e'),
    ];

    expect(search(extended, 'Alto P'), hasLength(1));
    expect(search(extended, 'Alto P').first.nome, 'Alto Preço');
    expect(search(extended, 'Alt Pre'), hasLength(1));
  });

  test('busca flexível com hífens, espaços ou texto compacto', () {
    for (final query in ['buscarmeeis', 'buscar me eis', 'buscar-me-eis']) {
      final result = search(catalog, query);
      expect(result, hasLength(1), reason: 'query: $query');
      expect(result.first.nome, 'Buscar-me-eis');
    }
  });

  test('título exato vem antes de match parcial no título', () {
    final extended = [
      ...catalog,
      _louvor(nome: 'Aleluia', numero: '500', pdfId: 'exact'),
    ];

    final result = search(extended, 'Aleluia');

    expect(result.first.nome, 'Aleluia');
    expect(result.map((l) => l.nome), contains('Aleluia ao Senhor'));
  });
}
