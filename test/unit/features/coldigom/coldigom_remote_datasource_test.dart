import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/coldigom/data/constants/coldigom_endpoints.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body);

  final int statusCode;
  final Object? body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

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

  test('PlpcgPraisesPageDto parseia materials slim sem lyrics', () {
    final page = PlpcgPraisesPageDto.fromJson({
      'data': [
        {
          'id': 'p1',
          'name': 'Hino',
          'number': '001',
          'rhythm': 'Fox',
          'author': '',
          'materials': [
            {
              'id': 'm1',
              'type': 'pdf',
              'r2_key': 'assets/praises/p1/m1.pdf',
              'url': null,
              'material_kind_name': 'Partitura',
            },
            {
              // Produção envia id null no placeholder de letra.
              'id': null,
              'type': 'lyrics',
              'r2_key': null,
              'url': null,
              'material_kind_name': 'Letra',
            },
          ],
        },
      ],
      'pagination': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
    });

    expect(page.data, hasLength(1));
    expect(page.data.first.materials, hasLength(2));
    expect(page.data.first.materials.first.type, 'pdf');
    expect(page.data.first.materials.last.type, 'lyrics');
    expect(page.pagination.total, 1);
  });

  test('PraiseDetailDto parseia tag_names opcional', () {
    final detail = PraiseDetailDto.fromJson({
      'id': 'p1',
      'name': 'Hino',
      'number': '001',
      'rhythm': 'Fox',
      'tag_names': 'PES,Coletânea',
      'materials': const [],
    });

    expect(detail.tagNames, ['PES', 'Coletânea']);
  });

  group('fetchMaterialTypesForKind', () {
    (ColdigomRemoteDatasource, _FixedAdapter) make(int status, Object? body) {
      final adapter = _FixedAdapter(status, body);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = adapter;
      return (ColdigomRemoteDatasource(dio), adapter);
    }

    test('devolve os types do kind, na ordem do Worker', () async {
      final (remote, adapter) = make(200, {
        'data': ['pdf', 'chord'],
      });
      final types = await remote.fetchMaterialTypesForKind('k1');
      expect(types, ['pdf', 'chord']);
      expect(
        adapter.lastRequest!.path,
        '${ColdigomEndpoints.materialKinds}/k1/types',
      );
    });

    test('resposta vazia devolve lista vazia', () async {
      final (remote, _) = make(200, null);
      expect(await remote.fetchMaterialTypesForKind('k1'), isEmpty);
    });
  });
}
