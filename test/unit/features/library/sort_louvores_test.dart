import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/library/domain/usecases/sort_louvores.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({
  required String nome,
  required String numero,
  String pdfId = 'id',
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
  late SortLouvores sort;

  setUp(() {
    sort = const SortLouvores();
  });

  test('ordena por número com parse numérico', () {
    final louvores = [
      _louvor(nome: 'C', numero: '10', pdfId: 'c'),
      _louvor(nome: 'A', numero: '2', pdfId: 'a'),
      _louvor(nome: 'B', numero: '10', pdfId: 'b'),
    ];

    final result = sort(louvores, sortBy: 'numero');

    expect(result.map((l) => l.pdfId), ['a', 'b', 'c']);
  });

  test('ordena por nome case-insensitive', () {
    final louvores = [
      _louvor(nome: 'zebra', numero: '1', pdfId: 'z'),
      _louvor(nome: 'Alpha', numero: '2', pdfId: 'a'),
      _louvor(nome: 'beta', numero: '3', pdfId: 'b'),
    ];

    final result = sort(louvores, sortBy: 'nome');

    expect(result.map((l) => l.pdfId), ['a', 'b', 'z']);
  });

  test('empate numérico usa pdfId como desempate', () {
    final louvores = [
      _louvor(nome: 'B', numero: '5', pdfId: 'b'),
      _louvor(nome: 'A', numero: '5', pdfId: 'a'),
    ];

    final result = sort(louvores, sortBy: 'numero');

    expect(result.map((l) => l.pdfId), ['a', 'b']);
  });
}
