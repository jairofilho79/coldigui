import 'package:flutter_test/flutter_test.dart';

import '../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  test('UC-01 integração — busca por número no índice do catálogo', () {
    final index = catalogIndexOf([
      catalogGroup(praiseId: 'p-100', number: '100', name: 'Louvor de teste'),
      catalogGroup(praiseId: 'p-101', number: '101', name: 'Outro louvor'),
    ]);

    final results = index.search('100');

    expect(results, hasLength(1));
    expect(results.first.groupId, 'p-100');
  });
}
