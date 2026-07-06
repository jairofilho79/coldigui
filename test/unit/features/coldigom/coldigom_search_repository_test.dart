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

  @override
  Future<List<PraiseSummaryDto>> search({
    required String query,
    int limit = 20,
    int page = 1,
  }) async {
    return _summaries;
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
    });

    test('query vazia retorna listas vazias', () async {
      final repo = ColdigomSearchRepositoryImpl(
        _FakeColdigomRemote(const [], const {}),
      );
      final result = await repo.search('   ');
      expect(result.groups, isEmpty);
      expect(result.louvores, isEmpty);
    });
  });
}
