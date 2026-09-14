// test/unit/features/catalog/catalog_source_test.dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/data/providers/catalog_source_provider.dart';
import 'package:coldigui/features/catalog/data/providers/plpcg_catalog_source_provider.dart';
import 'package:coldigui/features/catalog/data/sources/composite_catalog_source.dart';
import 'package:coldigui/features/catalog/data/sources/plpcg_catalog_source.dart';
import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/domain/ports/catalog_source.dart';
import 'package:coldigui/features/catalog/domain/ports/search_cancellation.dart';
import 'package:coldigui/features/catalog/domain/search/plpcg_search_index.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_group_id.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_filter_state.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:coldigui/features/coldigom/domain/repositories/coldigom_search_repository.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

final _plpcgGroupId = LouvorGroupId.compute(numero: '001', nome: 'Grande Deus');

final _plpcgPdfId = encodePdfId('ColAdultos/001.pdf');
final _plpcgCifraId = encodePdfId('ColAdultos/001-cifra.pdf');

final _plpcgPartitura = Louvor.fromManifest(
  nome: 'Grande Deus',
  numero: '001',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: '001.pdf',
  pdfId: _plpcgPdfId,
  groupId: _plpcgGroupId,
);

final _plpcgCifra = Louvor.fromManifest(
  nome: 'Grande Deus',
  numero: '001',
  categoria: 'Cifra nível I',
  classificacao: 'ColAdultos',
  pdf: '001-cifra.pdf',
  pdfId: _plpcgCifraId,
  groupId: _plpcgGroupId,
);

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

PlpcgCatalogSource _plpcgSource() => PlpcgCatalogSource(
  catalog: [_plpcgPartitura, _plpcgCifra],
  index: PlpcgSearchIndex.build([_plpcgPartitura, _plpcgCifra]),
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

CatalogQuery _query(String text, {Set<String>? materiais, int page = 1}) =>
    CatalogQuery(
      text: text,
      page: page,
      filters: CatalogFilterState(
        selectedMaterials: materiais ?? CatalogMaterials.defaultSelected,
        selectedArranjos: const {},
      ),
    );

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

  @override
  Future<ColdigomBrowseResult> browse(ColdigomBrowseQuery query) async {
    throw UnimplementedError();
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
  group('PlpcgCatalogSource', () {
    test('materialById devolve PdfMaterial do manifest', () async {
      final material = await _plpcgSource().materialById(_plpcgPdfId);

      expect(material, isA<PdfMaterial>());
      expect(material!.id, _plpcgPdfId);
    });

    test('materialById devolve null para id fora do manifest', () async {
      expect(
        await _plpcgSource().materialById(encodePdfId('ColAdultos/999.pdf')),
        isNull,
      );
    });

    test('groupById monta o grupo do manifest', () async {
      final group = await _plpcgSource().groupById(_plpcgGroupId);

      expect(group, isNotNull);
      expect(group!.totalPdfs, 2);
    });

    test('groupForMaterial agrupa irmãos PLPCG', () async {
      final group = await _plpcgSource().groupForMaterial(_plpcgPdfId);

      expect(group, isNotNull);
      expect(group!.totalMaterials, 2);
      expect(
        group.sections
            .expand((s) => s.materials)
            .every((m) => m.louvor.source == LouvorDataSource.plpcg),
        isTrue,
      );
    });

    test('não conhece cifra nem áudio Coldigom', () async {
      final source = _plpcgSource();

      expect(await source.materialById(_coldigomChordId), isNull);
      expect(await source.materialById(_coldigomAudioId), isNull);
    });
  });

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
  });

  group('CompositeCatalogSource', () {
    CompositeCatalogSource composite() => CompositeCatalogSource(
      plpcg: _plpcgSource(),
      coldigom: _coldigomSource(),
    );

    test('materialById despacha pelo espaço de ids', () async {
      final source = composite();

      final plpcg = await source.materialById(_plpcgPdfId);
      expect(plpcg, isA<PdfMaterial>());
      expect((plpcg! as PdfMaterial).louvor.source, LouvorDataSource.plpcg);

      final chord = await source.materialById(_coldigomChordId);
      expect(chord, isA<ChordMaterialRef>());
    });

    test('groupForMaterial não mistura PLPCG e Coldigom', () async {
      final source = composite();

      final plpcgGroup = await source.groupForMaterial(_plpcgPdfId);
      expect(
        plpcgGroup!.sections
            .expand((s) => s.materials)
            .every((m) => m.louvor.source == LouvorDataSource.plpcg),
        isTrue,
      );

      final coldigomGroup = await source.groupForMaterial(_coldigomPdfId);
      expect(coldigomGroup!.groupId, 'p1');
      expect(
        coldigomGroup.sections
            .expand((s) => s.materials)
            .every((m) => m.louvor.source == LouvorDataSource.coldigom),
        isTrue,
      );
    });

    test('groupById tenta o manifest e cai no cache Coldigom', () async {
      final source = composite();

      expect((await source.groupById(_plpcgGroupId))!.totalPdfs, 2);
      expect((await source.groupById('p1'))!.groupId, 'p1');
      expect(await source.groupById('desconhecido'), isNull);
    });
  });

  group('searchLocal / search', () {
    test('PlpcgCatalogSource.searchLocal roda o pipeline do índice', () {
      final groups = _plpcgSource().searchLocal(_query('Grande Deus'));

      expect(groups, hasLength(1));
      expect(groups.first.totalMaterials, 2);
    });

    test('PlpcgCatalogSource.searchLocal filtra por materiais', () {
      final groups = _plpcgSource().searchLocal(
        _query('Grande Deus', materiais: {CatalogMaterials.cifra}),
      );

      expect(groups, hasLength(1));
      expect(groups.first.totalMaterials, 1);
      expect(
        groups.first.sections.single.materials.single.louvor.pdfId,
        _plpcgCifraId,
      );
    });

    test('PlpcgCatalogSource.search não toca rede: página vazia', () async {
      final page = await _plpcgSource().search(_query('Grande Deus'));

      expect(page.groups, isEmpty);
      expect(page.page, 1);
      expect(page.hasNextPage, isFalse);
    });

    test('PlpcgCatalogSource sem índice devolve busca local vazia', () {
      expect(const PlpcgCatalogSource().searchLocal(_query('x')), isEmpty);
    });

    test('ColdigomCatalogSource.searchLocal é sempre vazio', () {
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

    test(
      'CompositeCatalogSource: searchLocal PLPCG, search Coldigom',
      () async {
        final repo = _RecordingSearchRepository(_searchResult());
        final source = CompositeCatalogSource(
          plpcg: _plpcgSource(),
          coldigom: _coldigomSource(searchRepository: repo),
        );

        final local = source.searchLocal(_query('Grande Deus'));
        expect(local, hasLength(1));
        expect(local.first.groupId, _plpcgGroupId);

        final page = await source.search(_query('Comigo'));
        expect(repo.calls, 1);
        expect(page.groups.single.groupId, 'p1');
      },
    );

    test(
      'CompositeCatalogSource.searchLocal concatena PLPCG e Coldigom (O16)',
      () {
        final plpcg = PlpcgCatalogSource(
          catalog: [_plpcgPartitura],
          index: PlpcgSearchIndex.build([_plpcgPartitura]),
        );
        final coldigomGroup = LouvorGroup(
          groupId: 'p1',
          numero: '001',
          nome: 'Grande Deus',
          sections: const [],
          chordMaterials: [_coldigomChord],
        );
        final coldigom = ColdigomCatalogSource(
          index: ColdigomSearchIndex.build([
            ColdigomIndexedPraise.build(
              praiseId: 'p1',
              numero: '001',
              nome: 'Grande Deus',
              searchTokens: 'grande deus 001',
              group: coldigomGroup,
            ),
          ]),
        );
        final composite = CompositeCatalogSource(
          plpcg: plpcg,
          coldigom: coldigom,
        );

        final hits = composite.searchLocal(const CatalogQuery(text: 'grande'));

        expect(hits.map((g) => g.groupId), [_plpcgGroupId, 'p1']);
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
      'plpcgCatalogSourceProvider não recompõe com merge Coldigom',
      () async {
        final container = ProviderContainer(
          overrides: [
            louvoresManifestOverride(
              LouvoresManifest.fromLouvores([_plpcgPartitura, _plpcgCifra]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(louvoresManifestProvider.future);

        final before = container.read(plpcgCatalogSourceProvider);
        final compositeBefore = container.read(catalogSourceProvider);

        container.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
          _coldigomPdf,
        ]);

        final after = container.read(plpcgCatalogSourceProvider);
        expect(identical(before, after), isTrue);
        expect(
          identical(compositeBefore, container.read(catalogSourceProvider)),
          isFalse,
          reason: 'o composite reflete o cache Coldigom novo',
        );
        expect(before.index.louvores, hasLength(2));
      },
    );

    test('catalogSourceProvider compõe as duas fontes', () async {
      final container = ProviderContainer(
        overrides: [
          louvoresManifestOverride(
            LouvoresManifest.fromLouvores([_plpcgPartitura, _plpcgCifra]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(louvoresManifestProvider.future);

      container.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
        _coldigomPdf,
      ]);

      final CatalogSource source = container.read(catalogSourceProvider);

      expect(await source.materialById(_plpcgPdfId), isA<PdfMaterial>());
      expect(await source.materialById(_coldigomPdfId), isA<PdfMaterial>());
      expect(source.searchLocal(_query('Grande Deus')), hasLength(1));
    });
  });
}
