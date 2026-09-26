import 'package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart';
import 'package:coldigui/features/library/domain/usecases/paginate_catalog_entries.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  final entries = <CatalogListEntry>[
    for (var i = 1; i <= 12; i++)
      SingleEntry(catalogGroup(praiseId: 'p$i', name: 'L$i')),
  ];

  test('pagina entradas com as regras de sempre (10 por padrão)', () {
    final page = const PaginateCatalogEntries()(
      entries,
      page: 2,
      itemsPerPage: 10,
    );

    expect(page.totalItems, 12);
    expect(page.totalPages, 2);
    expect([for (final e in page.items) describeEntry(e)], ['p11', 'p12']);
  });

  test('tamanho de página fora da lista cai em 10; página além do fim cai '
      'na última', () {
    final page = const PaginateCatalogEntries()(
      entries,
      page: 9,
      itemsPerPage: 7,
    );

    expect(page.itemsPerPage, 10);
    expect(page.page, 2);
  });

  test('vazio → uma página vazia', () {
    final page = const PaginateCatalogEntries()(
      const [],
      page: 1,
      itemsPerPage: 10,
    );

    expect(page.items, isEmpty);
    expect(page.totalPages, 1);
  });
}
