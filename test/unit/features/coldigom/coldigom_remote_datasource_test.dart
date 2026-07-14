import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PraisesPageDto parseia pagination e summary enriquecido', () {
    final page = PraisesPageDto.fromJson({
      'data': [
        {
          'id': 'p1',
          'name': 'Hino',
          'number': '001',
          'rhythm': 'Fox',
          'tonality': 'Dm',
          'category': 'Clamor',
          'author': '',
          'tag_ids': 't1,t2',
          'tag_names': 'PES,Coletânea',
        },
      ],
      'pagination': {'page': 2, 'limit': 10, 'total': 47, 'totalPages': 5},
    });

    expect(page.data, hasLength(1));
    expect(page.data.first.tonality, 'Dm');
    expect(page.data.first.tagNames, ['PES', 'Coletânea']);
    expect(page.pagination.total, 47);
    expect(page.pagination.totalPages, 5);
  });

  test('ColdigomPraisesQuery omite q vazio e serializa CSV', () {
    final params = const ColdigomPraisesQuery(
      tonalities: {'Dm', 'G'},
      tagIds: {'t1'},
      materialKindIds: {'k1'},
      page: 2,
      limit: 10,
      sort: 'name',
    ).toQueryParameters();

    expect(params.containsKey('q'), isFalse);
    expect(params['page'], 2);
    expect(params['limit'], 10);
    expect(params['sort'], 'name');
    expect(params['tonality'], anyOf('Dm,G', 'G,Dm'));
    expect(params['tags'], 't1');
    expect(params['materialKinds'], 'k1');
  });

  test('ColdigomFilterOptionsDto parseia facets', () {
    final options = ColdigomFilterOptionsDto.fromJson({
      'rhythms': ['Fox'],
      'tonalities': ['Dm'],
      'categories': ['Clamor'],
      'tags': [
        {'id': 't1', 'name': 'PES', 'count': 10},
      ],
    });

    expect(options.rhythms, ['Fox']);
    expect(options.tags.single.name, 'PES');
    expect(options.tags.single.count, 10);
  });
}
