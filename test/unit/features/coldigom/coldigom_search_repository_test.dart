import 'package:coldigui/features/catalog/domain/ports/search_cancellation.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/data/repositories/coldigom_search_repository_impl.dart';
import 'package:coldigui/features/coldigom/domain/repositories/coldigom_search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeColdigomRemote extends ColdigomRemoteDatasource {
  _FakeColdigomRemote(this._details, {this.blockUntilCancelled = false})
    : super(Dio());

  final List<PraiseDetailDto> _details;

  /// Nunca responde: só termina (com `DioExceptionType.cancel`) quando o
  /// [CancelToken] recebido é cancelado — espelha o Dio real.
  final bool blockUntilCancelled;

  ColdigomPraisesQuery? lastQuery;
  CancelToken? lastCancelToken;
  int fetchDetailCalls = 0;

  @override
  Future<PlpcgPraisesPageDto> listPlpcgPraises(
    ColdigomPraisesQuery query, {
    CancelToken? cancelToken,
  }) async {
    lastQuery = query;
    lastCancelToken = cancelToken;
    if (blockUntilCancelled) {
      final cancelError = await cancelToken!.whenCancel;
      throw cancelError;
    }
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
    throw StateError('fetchDetail não deve ser chamado no search');
  }
}

PraiseDetailDto _fullDetail(String praiseId) => PraiseDetailDto(
  id: praiseId,
  name: 'Comigo habita',
  number: '692',
  rhythm: 'Balada',
  materials: [
    MaterialDto(
      id: '$praiseId-m1',
      type: 'pdf',
      r2Key: 'assets/praises/$praiseId/m1.pdf',
      materialKindName: 'Partitura',
    ),
    MaterialDto(
      id: '$praiseId-m2',
      type: 'audio',
      r2Key: 'assets/praises/$praiseId/m1.mp3',
      materialKindName: 'Áudio',
    ),
    MaterialDto(
      id: '$praiseId-m3',
      type: 'chord',
      r2Key: 'assets/praises/$praiseId/m1.chord',
      materialKindName: 'Cifra',
    ),
    MaterialDto(
      id: '$praiseId-m4',
      type: 'youtube',
      url: 'https://youtu.be/abc',
      materialKindName: 'Vídeo',
    ),
  ],
);

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
  });

  group('ColdigomSearchRepositoryImpl — cancelamento', () {
    test(
      'cancelar cancela o CancelToken e lança SearchCancelledException',
      () async {
        final remote = _FakeColdigomRemote(const [], blockUntilCancelled: true);
        final repo = ColdigomSearchRepositoryImpl(remote);
        final cancellation = SearchCancellation();

        final future = repo.search('hino', cancellation: cancellation);
        await Future<void>.delayed(Duration.zero);
        expect(remote.lastCancelToken, isNotNull);
        expect(remote.lastCancelToken!.isCancelled, isFalse);

        cancellation.cancel();

        await expectLater(future, throwsA(isA<SearchCancelledException>()));
        expect(remote.lastCancelToken!.isCancelled, isTrue);
      },
    );

    test('cancelada antes de começar não chega a chamar o remote', () async {
      final remote = _FakeColdigomRemote(const [], blockUntilCancelled: true);
      final repo = ColdigomSearchRepositoryImpl(remote);
      final cancellation = SearchCancellation()..cancel();

      await expectLater(
        repo.search('hino', cancellation: cancellation),
        throwsA(isA<SearchCancelledException>()),
      );
      expect(remote.lastQuery, isNull);
    });

    test('sem cancellation o remote não recebe CancelToken', () async {
      final remote = _FakeColdigomRemote(const []);
      await ColdigomSearchRepositoryImpl(remote).search('hino');

      expect(remote.lastCancelToken, isNull);
    });
  });

  group('ColdigomSearchRepositoryImpl — escrita nos caches', () {
    ProviderContainer containerWith(ColdigomRemoteDatasource remote) {
      final container = ProviderContainer(
        overrides: [coldigomRemoteDatasourceProvider.overrideWithValue(remote)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('search grava louvores, faixas, cifras, meta e youtube', () async {
      final remote = _FakeColdigomRemote([_fullDetail('p1')]);
      final container = containerWith(remote);
      final repo = ColdigomSearchRepositoryImpl(
        remote,
        cache: container.read(coldigomCacheWriterProvider),
      );

      await repo.search('comigo');

      expect(container.read(coldigomLouvoresCacheProvider), isNotEmpty);
      expect(container.read(coldigomAudioTracksCacheProvider), isNotEmpty);
      expect(container.read(coldigomChordMaterialsCacheProvider), isNotEmpty);
      expect(container.read(coldigomPraiseMetaCacheProvider)['p1'], isNotNull);
      expect(container.read(coldigomYoutubeCacheProvider)['p1'], hasLength(1));
    });

    test('o provider do repositório já vem com o writer ligado', () async {
      final remote = _FakeColdigomRemote([_fullDetail('p3')]);
      final container = containerWith(remote);

      await container.read(coldigomSearchRepositoryProvider).search('comigo');

      expect(container.read(coldigomPraiseMetaCacheProvider)['p3'], isNotNull);
    });
  });
}
