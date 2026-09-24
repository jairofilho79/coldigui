// test/unit/features/catalog/catalog_source_test.dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/data/providers/catalog_source_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/domain/ports/catalog_source.dart';
import 'package:coldigui/features/catalog/domain/ports/search_cancellation.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:coldigui/features/coldigom/domain/repositories/coldigom_search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _plpcgPdfId = encodePdfId('ColAdultos/001.pdf');
final _coldigomPdfId = encodePdfId('assets/praises/p1/m1.pdf');
final _coldigomChordId = encodePdfId('assets/praises/p1/m1.chord');
final _coldigomAudioId = encodePdfId('assets/praises/p1/m1.mp3');

final _coldigomPdf = Louvor.fromManifest(
  nome: 'Comigo habita',
  numero: '002',
  categoria: 'Partitura',
  classificacao: 'Country',
  pdf: 'm1.pdf',
  pdfId: _coldigomPdfId,
  groupId: 'p1',
  source: LouvorDataSource.coldigom,
);

final _coldigomChord = ChordMaterial(
  chordId: _coldigomChordId,
  r2Key: 'assets/praises/p1/m1.chord',
  nome: 'Comigo habita',
  numero: '002',
  groupId: 'p1',
  categoria: 'Cifra',
  classificacao: 'Country',
);

final _coldigomTrack = AudioTrack(
  audioId: _coldigomAudioId,
  r2Key: 'assets/praises/p1/m1.mp3',
  nome: 'Comigo habita',
  numero: '002',
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'Country',
  source: LouvorDataSource.coldigom,
);

final _coldigomYoutube = YoutubeMaterial(
  id: 'yt-1',
  url: 'https://youtu.be/abc',
  nome: 'Comigo habita',
  numero: '002',
  groupId: 'p1',
  categoria: 'Vídeo',
  classificacao: 'Country',
);

ColdigomCatalogSource _coldigomSource({
  ColdigomSearchRepository? searchRepository,
  Map<String, List<YoutubeMaterial>> youtube = const {},
}) => ColdigomCatalogSource(
  louvores: {_coldigomPdfId: _coldigomPdf},
  chords: {_coldigomChordId: _coldigomChord},
  audioTracks: {_coldigomAudioId: _coldigomTrack},
  youtube: youtube,
  searchRepository: searchRepository,
);

CatalogQuery _query(String text, {int page = 1}) =>
    CatalogQuery(text: text, page: page);

/// Repositório de busca fake — registra a chamada e devolve um resultado fixo.
class _RecordingSearchRepository implements ColdigomSearchRepository {
  _RecordingSearchRepository(this.result);

  final ColdigomSearchResult result;
  String? lastQuery;
  int? lastPage;
  SearchCancellation? lastCancellation;
  int calls = 0;

  @override
  Future<ColdigomSearchResult> search(
    String query, {
    int page = 1,
    SearchCancellation? cancellation,
  }) async {
    calls++;
    lastQuery = query;
    lastPage = page;
    lastCancellation = cancellation;
    return result;
  }
}

ColdigomSearchResult _searchResult({bool hasNextPage = false, int page = 1}) {
  final groups = LouvorGroup.fromLouvores([_coldigomPdf]);
  return ColdigomSearchResult(
    groups: groups,
    louvores: [_coldigomPdf],
    page: page,
    hasNextPage: hasNextPage,
  );
}

void main() {
  group('ColdigomCatalogSource', () {
    test('materialById resolve pdf, cifra e áudio pelo cache', () async {
      final source = _coldigomSource();

      expect(await source.materialById(_coldigomPdfId), isA<PdfMaterial>());
      expect(
        await source.materialById(_coldigomChordId),
        isA<ChordMaterialRef>(),
      );
      expect(await source.materialById(_coldigomAudioId), isA<AudioMaterial>());
    });

    test('materialById devolve null com cache frio', () async {
      expect(
        await const ColdigomCatalogSource().materialById(_coldigomChordId),
        isNull,
      );
    });

    test('groupForMaterial junta PDF, cifra e áudio do praise', () async {
      final group = await _coldigomSource().groupForMaterial(_coldigomChordId);

      expect(group, isNotNull);
      expect(group!.groupId, 'p1');
      expect(group.totalMaterials, 3);
      expect(group.chordMaterials.single.chordId, _coldigomChordId);
      expect(group.audioTracks.single.audioId, _coldigomAudioId);
    });

    test('groupById devolve null para praise desconhecido', () async {
      expect(await _coldigomSource().groupById('p404'), isNull);
    });

    test(
      'findGroupForMaterial usa o praiseId do material, não a pasta do id',
      () {
        // Material movido: o `r2_key` vive na pasta de outro praise (~1400 PDFs
        // do coldigom). O grupo é o do `praiseId` que o adapter gravou.
        final movedId = encodePdfId('assets/praises/outro/m9.pdf');
        final moved = Louvor.fromManifest(
          nome: 'Comigo habita',
          numero: '002',
          categoria: 'Gestos',
          classificacao: 'Country',
          pdf: 'm9.pdf',
          pdfId: movedId,
          groupId: 'p1',
          source: LouvorDataSource.coldigom,
          praiseId: 'p1',
        );
        final source = ColdigomCatalogSource(
          louvores: {_coldigomPdfId: _coldigomPdf, movedId: moved},
        );

        final group = source.findGroupForMaterial(movedId);

        expect(group, isNotNull);
        expect(group!.groupId, 'p1');
        expect(group.totalPdfs, 2);
        // Sem o material em cache, o path do id continua a ser o fallback.
        expect(
          const ColdigomCatalogSource().findGroupForMaterial(movedId),
          isNull,
        );
      },
    );

    test('partsOfGroup devolve os caches do praise sem montar grupo', () {
      final parts = _coldigomSource(
        youtube: {
          'p1': [_coldigomYoutube],
        },
      ).partsOfGroup('p1');

      expect(parts.pdfs.single.pdfId, _coldigomPdfId);
      expect(parts.chords.single.chordId, _coldigomChordId);
      expect(parts.audioTracks.single.audioId, _coldigomAudioId);
      expect(parts.youtube.single.id, 'yt-1');
      expect(parts.lyrics, isNull);
      expect(parts.meta, isNull);
      expect(parts.isEmpty, isFalse);
    });

    test('partsOfGroup de praise desconhecido é empty', () {
      final parts = _coldigomSource().partsOfGroup('nope');
      expect(parts.isEmpty, isTrue);
      expect(_coldigomSource().partsOfGroup('').isEmpty, isTrue);
    });
  });

  group('searchLocal / search', () {
    test('ColdigomCatalogSource.searchLocal é vazio sem índice', () {
      expect(_coldigomSource().searchLocal(_query('Comigo')), isEmpty);
    });

    test('ColdigomCatalogSource.search delega ao repositório', () async {
      final repo = _RecordingSearchRepository(
        _searchResult(hasNextPage: true, page: 2),
      );
      final cancellation = SearchCancellation();

      final page = await _coldigomSource(searchRepository: repo)
          .search(_query('Comigo', page: 2), cancellation: cancellation);

      expect(repo.lastQuery, 'Comigo');
      expect(repo.lastPage, 2);
      expect(identical(repo.lastCancellation, cancellation), isTrue);
      expect(page.groups, hasLength(1));
      expect(page.page, 2);
      expect(page.hasNextPage, isTrue);
    });

    test(
      'ColdigomCatalogSource.search com query vazia não chama a rede',
      () async {
        final repo = _RecordingSearchRepository(_searchResult());

        final page = await _coldigomSource(searchRepository: repo)
            .search(_query('   '));

        expect(repo.calls, 0);
        expect(page.groups, isEmpty);
      },
    );
  });

  group('ColdigomCatalogSource youtube', () {
    test('findGroupById entrega os links do cache de YouTube', () {
      final group = _coldigomSource(
        youtube: {
          'p1': [_coldigomYoutube],
        },
      ).findGroupById('p1');

      expect(group!.youtubeMaterials.single.id, 'yt-1');
    });

    test('sem cache de YouTube o grupo continua sem links', () {
      expect(_coldigomSource().findGroupById('p1')!.youtubeMaterials, isEmpty);
    });
  });

  group('providers de fonte', () {
    test(
      'catalogSourceProvider é a fonte coldigom (spec fim-fonte-plpcg §2.1)',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
          _coldigomPdf,
        ]);

        final CatalogSource source = container.read(catalogSourceProvider);

        expect(source, isA<ColdigomCatalogSource>());
        expect(await source.materialById(_coldigomPdfId), isA<PdfMaterial>());
        expect(
          await source.materialById(_plpcgPdfId),
          isNull,
          reason: 'id legado já não é endereçável',
        );
      },
    );
  });
}
