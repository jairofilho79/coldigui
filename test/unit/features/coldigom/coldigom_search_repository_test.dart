import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/data/repositories/coldigom_search_repository_impl.dart';
import 'package:coldigui/features/coldigom/domain/repositories/coldigom_search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeColdigomRemote extends ColdigomRemoteDatasource {
  _FakeColdigomRemote(this._details) : super(Dio());

  final List<PraiseDetailDto> _details;
  ColdigomPraisesQuery? lastQuery;
  int fetchDetailCalls = 0;

  @override
  Future<PlpcgPraisesPageDto> listPlpcgPraises(
    ColdigomPraisesQuery query,
  ) async {
    lastQuery = query;
    return PlpcgPraisesPageDto(
      data: _details,
      pagination: PraisesPaginationDto(
        page: query.page,
        limit: query.limit,
        total: _details.length,
        totalPages: 1,
      ),
    );
  }

  @override
  Future<PraiseDetailDto> fetchDetail(String praiseId) async {
    fetchDetailCalls++;
    throw StateError('fetchDetail não deve ser chamado no search/browse');
  }
}

void main() {
  group('ColdigomSearchRepositoryImpl', () {
    test('retorna grupos a partir do endpoint PLPCG sem fetchDetail', () async {
      const praiseId = 'p1';
      final remote = _FakeColdigomRemote([
        const PraiseDetailDto(
          id: praiseId,
          name: 'Hino',
          number: '010',
          rhythm: 'Fox',
          materials: [
            MaterialDto(
              id: 'm1',
              type: 'pdf',
              r2Key: 'assets/praises/p1/m1.pdf',
              materialKindName: 'Partitura',
            ),
            MaterialDto(
              id: 'lyrics:p1',
              type: 'lyrics',
              materialKindName: 'Letra',
            ),
          ],
        ),
      ]);
      final repo = ColdigomSearchRepositoryImpl(remote);

      final ColdigomSearchResult result = await repo.search('hino');

      expect(result.groups, hasLength(1));
      expect(result.groups.first.nome, 'Hino');
      expect(result.louvores, hasLength(1));
      expect(result.hasNextPage, isFalse);
      expect(result.page, 1);
      expect(remote.fetchDetailCalls, 0);
    });

    test('query vazia retorna listas vazias', () async {
      final remote = _FakeColdigomRemote(const []);
      final repo = ColdigomSearchRepositoryImpl(remote);
      final result = await repo.search('   ');
      expect(result.groups, isEmpty);
      expect(result.louvores, isEmpty);
      expect(result.hasNextPage, isFalse);
      expect(remote.lastQuery, isNull);
    });

    test('passa page ao remote e hasNextPage quando página cheia', () async {
      final details = [
        for (var i = 0; i < 20; i++)
          PraiseDetailDto(
            id: 'p$i',
            name: 'Hino $i',
            number: '$i',
            rhythm: 'Fox',
            materials: [
              MaterialDto(
                id: 'm-$i',
                type: 'pdf',
                r2Key: 'assets/praises/p$i/m.pdf',
                materialKindName: 'Partitura',
              ),
            ],
          ),
      ];
      final remote = _FakeColdigomRemote(details);
      final repo = ColdigomSearchRepositoryImpl(remote);

      final result = await repo.search('hino', page: 2);

      expect(remote.lastQuery?.page, 2);
      expect(remote.lastQuery?.limit, 20);
      expect(result.page, 2);
      expect(result.hasNextPage, isTrue);
      expect(result.groups, hasLength(20));
      expect(remote.fetchDetailCalls, 0);
    });

    test('browse com q vazio usa total da API', () async {
      const praiseId = 'p1';
      final remote = _FakeColdigomRemote([
        const PraiseDetailDto(
          id: praiseId,
          name: 'Hino',
          number: '010',
          rhythm: 'Fox',
          materials: [
            MaterialDto(
              id: 'm1',
              type: 'pdf',
              r2Key: 'assets/praises/p1/m1.pdf',
              materialKindName: 'Partitura',
            ),
          ],
        ),
      ]);
      final repo = ColdigomSearchRepositoryImpl(remote);

      final result = await repo.browse(
        const ColdigomBrowseQuery(
          tonalities: {'Dm'},
          page: 1,
          limit: 10,
          sortBy: 'nome',
        ),
      );

      expect(remote.lastQuery?.q, isNull);
      expect(remote.lastQuery?.tonalities, {'Dm'});
      expect(remote.lastQuery?.sort, 'name');
      expect(result.groups, hasLength(1));
      expect(result.totalItems, 1);
      expect(result.louvores, hasLength(1));
      expect(remote.fetchDetailCalls, 0);
    });
  });
}
