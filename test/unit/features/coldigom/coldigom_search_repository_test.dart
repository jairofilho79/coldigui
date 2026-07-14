import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/data/repositories/coldigom_search_repository_impl.dart';
import 'package:coldigui/features/coldigom/domain/repositories/coldigom_search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeColdigomRemote extends ColdigomRemoteDatasource {
  _FakeColdigomRemote(this._summaries, this._details) : super(Dio());

  final List<PraiseSummaryDto> _summaries;
  final Map<String, PraiseDetailDto> _details;
  ColdigomPraisesQuery? lastQuery;

  @override
  Future<PraisesPageDto> listPraises(ColdigomPraisesQuery query) async {
    lastQuery = query;
    return PraisesPageDto(
      data: _summaries,
      pagination: PraisesPaginationDto(
        page: query.page,
        limit: query.limit,
        total: _summaries.length,
        totalPages: 1,
      ),
    );
  }

  @override
  Future<PraiseDetailDto> fetchDetail(String praiseId) async {
    return _details[praiseId]!;
  }
}

void main() {
  group('ColdigomSearchRepositoryImpl', () {
    test('retorna grupos a partir de detalhes com PDFs', () async {
      const praiseId = 'p1';
      final repo = ColdigomSearchRepositoryImpl(
        _FakeColdigomRemote(
          [const PraiseSummaryDto(id: praiseId, name: 'Hino', number: '010')],
          {
            praiseId: const PraiseDetailDto(
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
          },
        ),
      );

      final ColdigomSearchResult result = await repo.search('hino');

      expect(result.groups, hasLength(1));
      expect(result.groups.first.nome, 'Hino');
      expect(result.louvores, hasLength(1));
      expect(result.hasNextPage, isFalse);
      expect(result.page, 1);
    });

    test('query vazia retorna listas vazias', () async {
      final repo = ColdigomSearchRepositoryImpl(
        _FakeColdigomRemote(const [], const {}),
      );
      final result = await repo.search('   ');
      expect(result.groups, isEmpty);
      expect(result.louvores, isEmpty);
      expect(result.hasNextPage, isFalse);
    });

    test('passa page ao remote e hasNextPage quando página cheia', () async {
      final summaries = [
        for (var i = 0; i < 20; i++)
          PraiseSummaryDto(id: 'p$i', name: 'Hino $i', number: '$i'),
      ];
      final details = {
        for (final s in summaries)
          s.id: PraiseDetailDto(
            id: s.id,
            name: s.name,
            number: s.number,
            rhythm: 'Fox',
            materials: [
              MaterialDto(
                id: 'm-${s.id}',
                type: 'pdf',
                r2Key: 'assets/praises/${s.id}/m.pdf',
                materialKindName: 'Partitura',
              ),
            ],
          ),
      };
      final remote = _FakeColdigomRemote(summaries, details);
      final repo = ColdigomSearchRepositoryImpl(remote);

      final result = await repo.search('hino', page: 2);

      expect(remote.lastQuery?.page, 2);
      expect(remote.lastQuery?.limit, 20);
      expect(result.page, 2);
      expect(result.hasNextPage, isTrue);
      expect(result.groups, hasLength(20));
    });

    test('browse com q vazio usa total da API', () async {
      const praiseId = 'p1';
      final remote = _FakeColdigomRemote(
        [const PraiseSummaryDto(id: praiseId, name: 'Hino', number: '010')],
        {
          praiseId: const PraiseDetailDto(
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
        },
      );
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
    });
  });
}
