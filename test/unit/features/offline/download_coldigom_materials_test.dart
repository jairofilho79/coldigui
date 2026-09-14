import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/data/datasources/audio_bytes_datasource.dart';
import 'package:coldigui/features/chords/data/datasources/chord_content_datasource.dart';
import 'package:coldigui/features/chords/data/datasources/chord_content_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_local_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_figure_store.dart';
import 'package:coldigui/features/gestures/data/repositories/gesture_figure_repository.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/domain/entities/coldigom_download_progress.dart';
import 'package:coldigui/features/offline/domain/entities/local_audio_source.dart';
import 'package:coldigui/features/offline/domain/entities/offline_audio_entry.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_audio_repository.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/download_coldigom_materials.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// ------------------------------------------------------------- catálogo

ColdigomPraiseCache _row(
  String id,
  String number,
  List<Map<String, Object?>> materials,
) => ColdigomPraiseCache()
  ..praiseId = id
  ..number = number
  ..name = 'Louvor $number'
  ..author = ''
  ..rhythm = ''
  ..tonality = ''
  ..category = ''
  ..tags = const []
  ..lyrics = ''
  ..materialsJson = jsonEncode(materials)
  ..searchTokens = '';

Map<String, Object?> _m(String id, String kind, String type) => {
  'id': id,
  'kind': kind,
  'kindName': kind,
  'type': type,
  'r2': 'assets/praises/x/$id.$type',
};

String _r2(String id, String type) => 'assets/praises/x/$id.$type';

class _Catalog extends ColdigomCatalogLocalDatasource {
  const _Catalog(this.rows) : super(null);
  final List<ColdigomPraiseCache> rows;
  @override
  List<ColdigomPraiseCache> findAllSync() => rows;
}

// ------------------------------------------------------------------ PDF

class _PdfRepo implements OfflinePdfRepository {
  _PdfRepo({this.present = const {}, this.persistent = const {}});
  final Set<String> present;
  final Set<String> persistent;

  @override
  Future<List<OfflinePdfEntry>> listAll() async => [
    for (final id in present)
      OfflinePdfEntry(
        pdfId: id,
        absolutePath: '/x/$id',
        category: 'x',
        fileSize: 1,
        downloadedAt: DateTime(2026),
        isPersistent: persistent.contains(id),
      ),
  ];

  @override
  Future<Set<String>> lookupBatch(Set<String> pdfIds) async =>
      pdfIds.intersection(present);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _PdfLocal extends OfflinePdfLocalDatasource {
  const _PdfLocal(this.marked) : super(null);
  final Set<String> marked;
  @override
  Future<int> markPersistent(Set<String> pdfIds) async {
    marked.addAll(pdfIds);
    return pdfIds.length;
  }
}

// ---------------------------------------------------------------- áudio

class _AudioBytes extends AudioBytesDatasource {
  _AudioBytes(this.respond) : super(Dio(), apiBase: '', isWeb: false);
  final Future<Uint8List> Function(String r2Key) respond;
  final calls = <String>[];
  @override
  Future<Uint8List> fetch(String r2Key, {CancelToken? cancelToken}) {
    calls.add(r2Key);
    return respond(r2Key);
  }
}

class _AudioRepo implements OfflineAudioRepository {
  _AudioRepo({this.present = const {}, this.upsertThrows});
  final Set<String> present;
  final Object? upsertThrows;
  final upserted = <String>[];

  @override
  Future<Set<String>> lookupBatch(Set<String> audioIds) async =>
      audioIds.intersection(present);

  @override
  Future<OfflineAudioEntry> upsert({
    required String audioId,
    required String r2Key,
    required Uint8List bytes,
  }) async {
    if (upsertThrows != null) throw upsertThrows!;
    upserted.add(audioId);
    return OfflineAudioEntry(
      audioId: audioId,
      r2Key: r2Key,
      storageKey: '/x/$audioId',
      fileSize: bytes.length,
      downloadedAt: DateTime(2026),
    );
  }

  @override
  Future<LocalAudioSource?> lookup(String audioId) async => null;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

// ----------------------------------------------------------- cifra/gestos

class _ChordRemote extends ChordContentDatasource {
  _ChordRemote(this.respond) : super(Dio(), apiBase: '');
  final Future<String?> Function(String) respond;
  @override
  Future<String?> fetchContent(String r2Key) => respond(r2Key);
}

class _ChordLocal extends ChordContentLocalDatasource {
  _ChordLocal(this.store) : super(null);
  final Map<String, String> store;
  @override
  ChordCacheEntry? read(String r2Key) {
    final c = store[r2Key];
    return c == null
        ? null
        : ChordCacheEntry(content: c, fetchedAt: DateTime(2026));
  }

  @override
  void write(String r2Key, String content) => store[r2Key] = content;
}

class _GestureRemote extends GestureContentDatasource {
  _GestureRemote(this.respond) : super(Dio(), apiBase: '');
  final Future<String?> Function(String) respond;
  @override
  Future<String?> fetchContent(String r2Key) => respond(r2Key);
}

class _GestureLocal extends GestureContentLocalDatasource {
  _GestureLocal(this.store) : super(null);
  final Map<String, String> store;
  @override
  GestureCacheEntry? read(String r2Key) {
    final c = store[r2Key];
    return c == null
        ? null
        : GestureCacheEntry(content: c, fetchedAt: DateTime(2026));
  }

  @override
  void write(String r2Key, String content) => store[r2Key] = content;
}

class _Figures extends GestureFigureRepository {
  _Figures() : super(_NoStore(), Dio(), apiBase: '');
  final prefetched = <Set<String>>[];
  @override
  Future<void> prefetch(Iterable<String> r2Keys) async =>
      prefetched.add(r2Keys.toSet());
}

class _NoStore implements GestureFigureStorePort {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

// --------------------------------------------------------------- helpers

DioException _retryable() => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: DioExceptionType.connectionTimeout,
);

void main() {
  late Set<String> marked;
  late _Figures figures;

  DownloadColdigomMaterials build({
    required List<ColdigomPraiseCache> rows,
    _PdfRepo? pdfRepo,
    Set<String>? pdfFetched,
    Future<void> Function(
      String pdfId,
      String r2Key, {
      CancelToken? cancelToken,
    })?
    fetchPdf,
    _AudioBytes? audioBytes,
    _AudioRepo? audioRepo,
    Future<String?> Function(String)? chord,
    Map<String, String>? chordStore,
    Future<String?> Function(String)? gesture,
    Map<String, String>? gestureStore,
    int concurrency = 2,
  }) {
    marked = {};
    figures = _Figures();
    final fetched = pdfFetched ?? <String>{};
    return DownloadColdigomMaterials(
      catalog: _Catalog(rows),
      pdfRepository: pdfRepo ?? _PdfRepo(),
      pdfLocal: _PdfLocal(marked),
      fetchPdf:
          fetchPdf ??
          (id, _, {cancelToken}) async {
            fetched.add(id);
          },
      audioBytes: audioBytes ?? _AudioBytes((_) async => Uint8List(3)),
      audioRepository: audioRepo ?? _AudioRepo(),
      chordRemote: _ChordRemote(chord ?? (_) async => '{t: x}'),
      chordLocal: _ChordLocal(chordStore ?? {}),
      gestureRemote: _GestureRemote(gesture ?? (_) async => '{"cards":[]}'),
      gestureLocal: _GestureLocal(gestureStore ?? {}),
      figures: figures,
      figureKeysFor: (_) async => {'fig/a.png', 'fig/b.png'},
      concurrency: concurrency,
    );
  }

  test('filtra por kind/tipo e baixa cada tipo pelo caminho certo', () async {
    final pdfFetched = <String>{};
    final chordStore = <String, String>{};
    final gestureStore = <String, String>{};
    final audioRepo = _AudioRepo();
    final usecase = build(
      rows: [
        _row('p1', '001', [
          _m('a', 'k-pdf', 'pdf'),
          _m('b', 'k-mp3', 'mp3'),
          _m('c', 'k-chord', 'chord'),
          _m('d', 'k-gest', 'gestures'),
          _m('e', 'k-fora', 'pdf'),
        ]),
      ],
      pdfFetched: pdfFetched,
      audioRepo: audioRepo,
      chordStore: chordStore,
      gestureStore: gestureStore,
    );
    final progress = <ColdigomDownloadProgress>[];

    final result = await usecase(
      kindIds: {'k-pdf', 'k-mp3', 'k-chord', 'k-gest'},
      onProgress: progress.add,
    );

    expect(result.done, 4);
    expect(result.skipped, 0);
    expect(result.failed, isEmpty);
    expect(result.bytes, 3 + '{t: x}'.length + '{"cards":[]}'.length);
    expect(pdfFetched, {encodePdfId(_r2('a', 'pdf'))});
    expect(audioRepo.upserted, [encodePdfId(_r2('b', 'mp3'))]);
    expect(chordStore[_r2('c', 'chord')], '{t: x}');
    expect(gestureStore[_r2('d', 'gestures')], '{"cards":[]}');
    expect(figures.prefetched.single, {'fig/a.png', 'fig/b.png'});
    // Emissão inicial (antes dos workers), com os totais já conhecidos.
    expect(progress.first.doneTotal, 0);
    expect(progress.first.total, 4);
    expect(progress.last.doneTotal, 4);
    expect(progress.last.total, 4);
    expect(progress.skip(1).map((p) => p.currentTitle).toSet(), {
      '001 · Louvor 001',
    });
  });

  test('presentes são saltados; PDF LRU é promovido sem download; cifra 404 conta como feito', () async {
    final pdfFetched = <String>{};
    final pdfA = encodePdfId(_r2('a', 'pdf'));
    final pdfF = encodePdfId(_r2('f', 'pdf'));
    final audioB = encodePdfId(_r2('b', 'mp3'));
    final chordStore = <String, String>{_r2('c', 'chord'): 'já tenho'};
    final usecase = build(
      rows: [
        _row('p1', '001', [
          _m('a', 'k', 'pdf'),
          _m('b', 'k', 'mp3'),
          _m('c', 'k', 'chord'),
          _m('c2', 'k', 'chord'),
          _m('f', 'k', 'pdf'),
        ]),
      ],
      // pdfA: presente, ainda em LRU (deve ser promovido).
      // pdfF: presente e já persistente (não deve ser re-marcado).
      pdfRepo: _PdfRepo(present: {pdfA, pdfF}, persistent: {pdfF}),
      pdfFetched: pdfFetched,
      audioRepo: _AudioRepo(present: {audioB}),
      chord: (_) async => null,
      chordStore: chordStore,
    );

    final result = await usecase(kindIds: {'k'});

    expect(result.skipped, 4);
    expect(result.done, 1);
    expect(pdfFetched, isEmpty);
    expect(marked, {pdfA});
    expect(chordStore[_r2('c2', 'chord')], '');
  });

  test('falha individual (após retries) não para; DioException retryável é retentada', () async {
    var attempts = 0;
    final usecase = build(
      rows: [
        _row('p1', '001', [_m('a', 'k', 'mp3'), _m('b', 'k', 'mp3')]),
      ],
      audioBytes: _AudioBytes((key) async {
        if (key.contains('/a.')) {
          attempts++;
          throw _retryable();
        }
        return Uint8List(1);
      }),
    );

    final result = await usecase(kindIds: {'k'});

    expect(result.done, 1);
    expect(result.failed.single.materialId, 'a');
    expect(result.failed.single.cause, isA<DioException>());
    expect(attempts, 3);
    expect(result.cancelled, isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'PDF não é retentado aqui — FetchAndStorePdf já tenta internamente',
    () async {
      var pdfAttempts = 0;
      final usecase = build(
        rows: [
          _row('p1', '001', [_m('a', 'k', 'pdf')]),
        ],
        fetchPdf: (id, r2Key, {cancelToken}) async {
          pdfAttempts++;
          throw _retryable();
        },
      );

      final result = await usecase(kindIds: {'k'});

      expect(pdfAttempts, 1);
      expect(result.done, 0);
      expect(result.failed.single.materialId, 'a');
      expect(result.failed.single.cause, isA<DioException>());
      expect(result.cancelled, isFalse);
    },
  );

  test('cancelToken chega ao fetchPdf da fila de PDFs', () async {
    final token = CancelToken();
    CancelToken? received;
    final usecase = build(
      rows: [
        _row('p1', '001', [_m('a', 'k', 'pdf')]),
      ],
      fetchPdf: (id, r2Key, {cancelToken}) async {
        received = cancelToken;
      },
    );

    await usecase(kindIds: {'k'}, cancelToken: token);

    expect(received, same(token));
  });

  test(
    'cancelamento durante fetch de PDF em voo não vira falha (só stopped)',
    () async {
      final gate = Completer<void>();
      final token = CancelToken();
      final usecase = build(
        rows: [
          _row('p1', '001', [_m('a', 'k', 'pdf')]),
        ],
        fetchPdf: (id, r2Key, {cancelToken}) async {
          await gate.future;
          if (cancelToken?.isCancelled ?? false) {
            throw DioException(
              requestOptions: RequestOptions(path: '/x'),
              type: DioExceptionType.cancel,
            );
          }
        },
        concurrency: 1,
      );

      final future = usecase(kindIds: {'k'}, cancelToken: token);
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      gate.complete();
      final result = await future;

      expect(result.cancelled, isTrue);
      expect(result.failed, isEmpty);
      expect(result.done, 0);
    },
  );

  test(
    'gestos 404 grava marcador negativo e não faz prefetch de figuras',
    () async {
      final gestureStore = <String, String>{};
      final usecase = build(
        rows: [
          _row('p1', '001', [_m('a', 'k', 'gestures')]),
        ],
        gesture: (_) async => null,
        gestureStore: gestureStore,
      );

      final result = await usecase(kindIds: {'k'});

      expect(result.done, 1);
      expect(gestureStore[_r2('a', 'gestures')], '');
      expect(figures.prefetched, isEmpty);
    },
  );

  test('progresso reporta doneInKind/totalInKind por kind, além da emissão inicial', () async {
    final progress = <ColdigomDownloadProgress>[];
    final usecase = build(
      rows: [
        for (var i = 0; i < 3; i++)
          _row('p$i', '00$i', [_m('m$i', 'k', 'mp3')]),
      ],
    );

    final result = await usecase(kindIds: {'k'}, onProgress: progress.add);

    expect(result.done, 3);
    expect(progress.first.doneTotal, 0);
    expect(progress.first.total, 3);
    expect(progress.first.kindId, '');
    final perItem = progress.skip(1).toList();
    expect(perItem, hasLength(3));
    expect(perItem.map((p) => p.totalInKind).toSet(), {3});
    expect(perItem.map((p) => p.doneInKind).toList(), [1, 2, 3]);
  });

  test('falta de espaço para tudo e devolve o parcial', () async {
    final usecase = build(
      rows: [
        _row('p1', '001', [_m('a', 'k', 'mp3')]),
        _row('p2', '002', [_m('b', 'k', 'mp3')]),
        _row('p3', '003', [_m('c', 'k', 'mp3')]),
      ],
      audioRepo: _AudioRepo(
        upsertThrows: const InsufficientDiskSpaceException(
          requiredBytes: 1,
          availableBytes: 0,
        ),
      ),
      concurrency: 1,
    );

    final result = await usecase(kindIds: {'k'});

    expect(result.cancelled, isTrue);
    expect(result.done, 0);
    expect(result.failed.single.cause, isA<InsufficientDiskSpaceException>());
  });

  test('falta de espaço com concorrência 2: só os alvos em voo falham, nenhum outro é iniciado', () async {
    final audio = _AudioBytes((_) async => Uint8List(1));
    final usecase = build(
      rows: [
        for (var i = 0; i < 5; i++)
          _row('p$i', '00$i', [_m('m$i', 'k', 'mp3')]),
      ],
      audioBytes: audio,
      audioRepo: _AudioRepo(
        upsertThrows: const InsufficientDiskSpaceException(
          requiredBytes: 1,
          availableBytes: 0,
        ),
      ),
      concurrency: 2,
    );

    final result = await usecase(kindIds: {'k'});

    expect(result.cancelled, isTrue);
    expect(result.done, 0);
    // No máximo os 2 alvos que os 2 workers já tinham em voo quando a
    // primeira quota estourou — nenhum dos outros 3 chega a ser tentado.
    expect(audio.calls.length, lessThanOrEqualTo(2));
    expect(result.failed, isNotEmpty);
    expect(result.failed.length, lessThanOrEqualTo(2));
    expect(
      result.failed.every((f) => f.cause is InsufficientDiskSpaceException),
      isTrue,
    );
  });

  test('cancelamento devolve o parcial e não inicia mais alvos', () async {
    final gate = Completer<void>();
    final token = CancelToken();
    final audio = _AudioBytes((key) async {
      if (key.contains('/a.')) {
        await gate.future;
        return Uint8List(1);
      }
      return Uint8List(1);
    });
    final usecase = build(
      rows: [
        _row('p1', '001', [_m('a', 'k', 'mp3')]),
        _row('p2', '002', [_m('b', 'k', 'mp3')]),
        _row('p3', '003', [_m('c', 'k', 'mp3')]),
      ],
      audioBytes: audio,
      concurrency: 1,
    );

    final future = usecase(kindIds: {'k'}, cancelToken: token);
    await Future<void>.delayed(Duration.zero);
    token.cancel();
    gate.complete();
    final result = await future;

    expect(result.cancelled, isTrue);
    expect(result.done, 1);
    expect(audio.calls, hasLength(1));
  });

  test('concorrência limitada ao valor configurado', () async {
    var inFlight = 0;
    var maxInFlight = 0;
    final usecase = build(
      rows: [
        for (var i = 0; i < 6; i++)
          _row('p$i', '00$i', [_m('m$i', 'k', 'mp3')]),
      ],
      audioBytes: _AudioBytes((_) async {
        inFlight++;
        maxInFlight = maxInFlight < inFlight ? inFlight : maxInFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return Uint8List(1);
      }),
      concurrency: 2,
    );

    final result = await usecase(kindIds: {'k'});

    expect(result.done, 6);
    expect(maxInFlight, 2);
  });
}
