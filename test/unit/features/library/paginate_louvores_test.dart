import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/library/domain/usecases/paginate_louvores.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({required String nome, String pdfId = 'id'}) =>
    Louvor.fromManifest(
      nome: nome,
      numero: '1',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '1.pdf',
      pdfId: pdfId,
    );

void main() {
  late PaginateLouvores paginate;
  late List<Louvor> louvores;

  setUp(() {
    paginate = const PaginateLouvores();
    louvores = List.generate(
      25,
      (i) => _louvor(nome: 'Louvor $i', pdfId: 'id-$i'),
    );
  });

  test('fatia 10 itens na primeira página', () {
    final result = paginate(louvores, page: 1, itemsPerPage: 10);

    expect(result.items, hasLength(10));
    expect(result.page, 1);
    expect(result.totalItems, 25);
    expect(result.totalPages, 3);
  });

  test('suporta tamanhos 25, 50 e 100', () {
    final result25 = paginate(louvores, page: 1, itemsPerPage: 25);
    expect(result25.items, hasLength(25));

    final large = List.generate(
      60,
      (i) => _louvor(nome: 'Louvor $i', pdfId: 'big-$i'),
    );
    final result50 = paginate(large, page: 2, itemsPerPage: 50);
    expect(result50.items, hasLength(10));
    expect(result50.page, 2);
  });

  test('itemsPerPage inválido usa 10', () {
    final result = paginate(louvores, page: 1, itemsPerPage: 15);

    expect(result.itemsPerPage, 10);
  });

  test('page fora do intervalo é clamped', () {
    final result = paginate(louvores, page: 99, itemsPerPage: 10);

    expect(result.page, 3);
    expect(result.items, hasLength(5));
  });

  test('lista vazia retorna página 1', () {
    final result = paginate(const [], page: 5, itemsPerPage: 10);

    expect(result.page, 1);
    expect(result.totalPages, 1);
    expect(result.items, isEmpty);
  });
}
