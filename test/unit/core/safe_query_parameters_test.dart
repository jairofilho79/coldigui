import 'package:coldigui/core/utils/safe_query_parameters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('devolve queryParameters normal quando bem formado', () {
    final uri = Uri.parse('/?sharepdfs=a,b&sharename=Ensaio');
    expect(safeQueryParameters(uri), {
      'sharepdfs': 'a,b',
      'sharename': 'Ensaio',
    });
  });

  test('descarta apenas o par com % inválido sem lançar', () {
    final uri = Uri.parse('/?sharename=%E0%A4%A&sharepdfs=a');
    expect(safeQueryParameters(uri), {'sharepdfs': 'a'});
  });

  test('devolve mapa vazio quando todos os pares são inválidos', () {
    final uri = Uri.parse('/?sharename=%E0%A4%A');
    expect(safeQueryParameters(uri), <String, String>{});
  });

  test('devolve mapa vazio quando não há query', () {
    expect(safeQueryParameters(Uri.parse('/')), <String, String>{});
  });
}
