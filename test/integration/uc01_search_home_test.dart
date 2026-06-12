import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/usecases/search_louvor_by_number_or_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UC-01 integração — busca por número no catálogo em memória', () {
    const search = SearchLouvorByNumberOrText();
    final catalog = [
      Louvor.fromManifest(
        nome: 'Louvor de teste',
        numero: '100',
        categoria: 'Partitura',
        classificacao: 'ColAdultos',
        pdf: '100.pdf',
        pdfId: 'test-id',
      ),
    ];

    final results = search(catalog, '100');

    expect(results, hasLength(1));
    expect(results.first.pdfId, 'test-id');
  });
}
