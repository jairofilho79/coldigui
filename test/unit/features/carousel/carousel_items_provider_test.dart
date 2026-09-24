import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../support/test_overrides.dart';

final _pdfA = encodePdfId('ColAdultos/001.pdf');
final _pdfB = encodePdfId('ColAdultos/002.pdf');
final _audioA = encodePdfId('ColAdultos/001.mp3');

Louvor _louvor(String pdfId, String numero, String nome) => Louvor(
  pdfId: pdfId,
  pdf: '$numero.pdf',
  groupId: numero,
  numero: numero,
  nome: nome,
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  searchTitleNorm: nome.toLowerCase(),
  searchContentTokens: const [],
  searchCompactContent: '',
  source: LouvorDataSource.plpcg,
);

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('carousel_items_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<ProviderContainer> boot({
    required List<PlaylistEntry> entries,
    Map<String, Object> extraPrefs = const {},
  }) async {
    await repository.create(
      nome: 'Ativa',
      entries: entries,
      playlistId: 'p1',
      salva: false,
    );
    SharedPreferences.setMockInitialValues({
      kActivePlaylistIdPrefsKey: 'p1',
      ...extraPrefs,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        playlistRepositoryProvider.overrideWithValue(repository),
        coldigomLouvoresOverride([
          _louvor(_pdfA, '001', 'Santo'),
          _louvor(_pdfB, '002', 'Aleluia'),
        ]),
      ],
    );
    addTearDown(container.dispose);
    container.read(playlistsProvider);
    await _flush();
    return container;
  }

  test('carouselItemsProvider devolve todas as entradas na ordem, com index global', () async {
    final c = await boot(
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
        PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
      ],
    );

    final items = c.read(carouselItemsProvider);

    expect(items.map((i) => i.materialId), [_pdfA, _audioA, _pdfB]);
    expect(items.map((i) => i.index), [0, 1, 2]);
    expect(items.map((i) => i.key), [_pdfA, _audioA, _pdfB]);
    expect(items.first.numero, '001');
    expect(items.first.nome, 'Santo');
    expect(items.last.label, '002 — Aleluia');
  });

  test(
    'readableCarouselItemsProvider filtra áudio e preserva o index',
    () async {
      final c = await boot(
        entries: [
          PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
          PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
        ],
      );

      final items = c.read(readableCarouselItemsProvider);

      expect(items.map((i) => i.materialId), [_pdfA, _pdfB]);
      expect(items.map((i) => i.index), [0, 2]);
    },
  );

  test('entrada de áudio é enriquecida pela faixa do cache Coldigom', () async {
    final c = await boot(
      entries: [PlaylistEntry(id: _audioA, kind: MaterialKind.audio)],
    );
    c.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
      AudioTrack(
        audioId: _audioA,
        r2Key: 'ColAdultos/001.mp3',
        nome: 'Santo',
        numero: '001',
        groupId: '001',
        categoria: 'Coro',
        classificacao: 'ColAdultos',
      ),
    ]);

    final item = c.read(carouselItemsProvider).single;

    expect(item.isAudio, isTrue);
    expect(item.numero, '001');
    expect(item.nome, 'Santo');
    expect(item.categoria, 'Coro');
  });

  test('readerCarouselPositionProvider ignora entradas de áudio', () async {
    final c = await boot(
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
        PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
      ],
    );

    final position = c.read(readerCarouselPositionProvider(_pdfA))!;

    expect(position.currentIndex, 1);
    expect(position.total, 2);
    expect(position.nextKey, _pdfB);
    expect(position.previousKey, isNull);
  });

  test('audioCarouselItemsProvider só áudio e preserva o index', () async {
    final c = await boot(
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
      ],
    );

    final items = c.read(audioCarouselItemsProvider);

    expect(items.map((i) => i.materialId), [_audioA]);
    expect(items.single.kind, MaterialKind.audio);
    expect(items.single.index, 1);
  });

  test('activeMaterialIdsProvider junta todos os ids', () async {
    final c = await boot(
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
      ],
    );

    expect(c.read(activeMaterialIdsProvider), {_pdfA, _audioA});
  });

  test(
    'gesto na lista ativa usa nome, número e categoria do documento de gestos',
    () async {
      final gestureId = encodePdfId('assets/praises/p1/m1.gestures');
      final c = await boot(
        entries: [PlaylistEntry(id: gestureId, kind: MaterialKind.gesture)],
      );
      c.read(coldigomGestureMaterialsCacheProvider.notifier).mergeGestures([
        GestureMaterial(
          gestureId: gestureId,
          r2Key: 'assets/praises/p1/m1.gestures',
          nome: 'Comigo habita',
          numero: '692',
          groupId: 'p1',
          categoria: 'Gestos',
          classificacao: 'Balada',
        ),
      ]);

      final item = c.read(carouselItemsProvider).single;

      expect(item.numero, '692');
      expect(item.nome, 'Comigo habita');
      expect(item.categoria, 'Gestos');
    },
  );

  test('material sem metadado cai no fallback de nome truncado', () async {
    const orfao = 'idmuitolongodemais';
    final c = await boot(
      entries: [PlaylistEntry(id: orfao, kind: MaterialKind.pdf)],
    );

    final item = c.read(carouselItemsProvider).single;

    expect(item.numero, '');
    expect(item.nome, 'idmuitolongo…');
  });

  test('repetição do mesmo louvor gera duas chaves distintas', () async {
    final c = await boot(
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
      ],
    );

    expect(c.read(carouselItemsProvider).map((i) => i.key), [
      _pdfA,
      '$_pdfA#1',
    ]);
  });

  test(
    'carouselFocusedIndexProvider foca por chave e sobrevive a reorder',
    () async {
      final c = await boot(
        entries: [
          PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
        ],
      );

      c.read(carouselFocusedIndexProvider.notifier).focusKey(_pdfB);
      expect(c.read(carouselFocusedIndexProvider), 1);

      await c.read(activePlaylistEditorProvider.notifier).reorder([
        _pdfB,
        _pdfA,
      ]);
      await _flush();

      expect(c.read(carouselItemsProvider).map((i) => i.materialId), [
        _pdfB,
        _pdfA,
      ]);
      expect(c.read(carouselFocusedIndexProvider), 0);
    },
  );

  test(
    'foco persistido na pref antiga é lido como chave da primeira ocorrência',
    () async {
      final c = await boot(
        entries: [
          PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
          PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
        ],
        extraPrefs: {kCarouselFocusedPdfIdPrefsKey: _pdfB},
      );

      expect(c.read(carouselFocusedIndexProvider), 1);
    },
  );

  test('focusedCarouselItemProvider devolve o item focado', () async {
    final c = await boot(
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
      ],
    );

    c.read(carouselFocusedIndexProvider.notifier).focusKey(_pdfB);

    expect(c.read(focusedCarouselItemProvider)!.materialId, _pdfB);
  });
}
