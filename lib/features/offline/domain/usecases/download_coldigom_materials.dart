import 'dart:math' show min;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../audio_player/data/datasources/audio_bytes_datasource.dart';
import '../../../catalog/domain/entities/material_kind_taxonomy.dart';
import '../../../chords/data/datasources/chord_content_datasource.dart';
import '../../../chords/data/datasources/chord_content_local_datasource.dart';
import '../../../coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import '../../../gestures/data/datasources/gesture_content_datasource.dart';
import '../../../gestures/data/datasources/gesture_content_local_datasource.dart';
import '../../../gestures/data/repositories/gesture_figure_repository.dart';
import '../../../score_reader/data/repositories/score_file_repository.dart';
import '../../data/datasources/offline_pdf_local_datasource.dart';
import '../entities/coldigom_download_progress.dart';
import '../entities/coldigom_download_target.dart';
import '../entities/offline_reader_material.dart';
import '../exceptions/offline_bulk_exceptions.dart';
import '../repositories/offline_audio_repository.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/download_retry.dart';

/// Baixa e persiste um PDF como persistente (`FetchAndStorePdf` em produção).
/// [cancelToken] é o mesmo token de [DownloadColdigomMaterials.call] — «Parar»
/// interrompe um PDF em voo, não só os alvos ainda não iniciados.
typedef FetchColdigomPdf = Future<void> Function(
  String pdfId,
  String r2Key, {
  CancelToken? cancelToken,
});

/// `r2Key`s das figuras de um documento `.gestures` (parse + dicionário).
typedef GestureFigureKeysResolver = Future<Set<String>?> Function(
  String gestureJson,
);

/// Download dos materiais Coldigom dos [kindIds] escolhidos (spec §5.2, O12).
///
/// Idempotente e retomável por construção: enumera do catálogo local, salta
/// o que já está no índice/cache e pode ser parado e chamado de novo sem
/// checkpoint. Cada tipo persiste onde já persistia (C1/O7): PDF no
/// `OfflinePdfIndex` (LRU presente é só promovido), áudio no índice novo,
/// cifra e gestos nos caches Isar (404 vira marcador negativo e conta como
/// feito — o sheet já sabe que «não existe»), partitura editável no store de
/// partituras (o mesmo que o leitor `/partitura` lê primeiro).
///
/// Falha individual → `failed` e segue para o próximo;
/// [InsufficientDiskSpaceException] ou cancelamento → para tudo e devolve o
/// parcial (`cancelled: true`).
class DownloadColdigomMaterials {
  DownloadColdigomMaterials({
    required ColdigomCatalogLocalDatasource catalog,
    required OfflinePdfRepository pdfRepository,
    required OfflinePdfLocalDatasource pdfLocal,
    required FetchColdigomPdf fetchPdf,
    required AudioBytesDatasource audioBytes,
    required OfflineAudioRepository audioRepository,
    required ChordContentDatasource chordRemote,
    required ChordContentLocalDatasource chordLocal,
    required GestureContentDatasource gestureRemote,
    required GestureContentLocalDatasource gestureLocal,
    required GestureFigureRepository figures,
    required GestureFigureKeysResolver figureKeysFor,
    required int concurrency,
    GestureFigureKeysResolver? cachedFigureKeysFor,
    Future<void> Function(Set<String> praiseIds)? restoreLyrics,
    ScoreFileRepository? scoreFiles,
  }) : _catalog = catalog, // ignore: prefer_initializing_formals
       _pdfRepository = pdfRepository, // ignore: prefer_initializing_formals
       _pdfLocal = pdfLocal, // ignore: prefer_initializing_formals
       _fetchPdf = fetchPdf, // ignore: prefer_initializing_formals
       _audioBytes = audioBytes, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _audioRepository = audioRepository,
       _chordRemote = chordRemote, // ignore: prefer_initializing_formals
       _chordLocal = chordLocal, // ignore: prefer_initializing_formals
       _gestureRemote = gestureRemote, // ignore: prefer_initializing_formals
       _gestureLocal = gestureLocal, // ignore: prefer_initializing_formals
       _figures = figures, // ignore: prefer_initializing_formals
       _figureKeysFor = figureKeysFor, // ignore: prefer_initializing_formals
       _cachedFigureKeysFor = cachedFigureKeysFor ?? figureKeysFor,
       _restoreLyrics = restoreLyrics, // ignore: prefer_initializing_formals
       _scoreFiles = scoreFiles, // ignore: prefer_initializing_formals
       _concurrency = concurrency < 1 ? 1 : concurrency;

  final ColdigomCatalogLocalDatasource _catalog;
  final OfflinePdfRepository _pdfRepository;
  final OfflinePdfLocalDatasource _pdfLocal;
  final FetchColdigomPdf _fetchPdf;
  final AudioBytesDatasource _audioBytes;
  final OfflineAudioRepository _audioRepository;
  final ChordContentDatasource _chordRemote;
  final ChordContentLocalDatasource _chordLocal;
  final GestureContentDatasource _gestureRemote;
  final GestureContentLocalDatasource _gestureLocal;
  final GestureFigureRepository _figures;
  final GestureFigureKeysResolver _figureKeysFor;
  final GestureFigureKeysResolver _cachedFigureKeysFor;
  final Future<void> Function(Set<String> praiseIds)? _restoreLyrics;

  /// `null` só em testes que não exercitam partituras.
  final ScoreFileRepository? _scoreFiles;
  final int _concurrency;

  Future<bool> isMaterialAvailable(OfflineReaderMaterial material) async {
    final (:kind, :id, :key) = material;
    return switch (kind) {
      MaterialKind.pdf =>
        (await _pdfRepository.lookup(id))?.isPersistent ?? false,
      MaterialKind.audio => (await _audioRepository.lookupBatch({
        id,
      })).contains(id),
      MaterialKind.chord =>
        parseChordSongOrNull(_chordLocal.read(key)?.content ?? '') != null,
      MaterialKind.gesture => _gestureAvailable(
        _gestureLocal.read(key)?.content,
      ),
      _ => throw ArgumentError.value(
        kind,
        'kind',
        'Not an offline reader file',
      ),
    };
  }

  Future<void> downloadMaterial(OfflineReaderMaterial material) async {
    if (await isMaterialAvailable(material)) return;
    if (material.kind == MaterialKind.pdf &&
        await _pdfRepository.lookup(material.id) != null) {
      await _pdfLocal.markPersistent({material.id});
    } else {
      await _download(material, null);
    }
    if (!await isMaterialAvailable(material)) {
      throw StateError('Material not available after download: ${material.id}');
    }
  }

  Future<void> removeMaterial(OfflineReaderMaterial material) async {
    final (:kind, :id, :key) = material;
    switch (kind) {
      case MaterialKind.pdf:
        await _pdfRepository.remove(id);
      case MaterialKind.audio:
        await _audioRepository.remove(id);
      case MaterialKind.chord:
        _chordLocal.remove(key);
      case MaterialKind.gesture:
        _gestureLocal.remove(key);
      default:
        throw ArgumentError.value(kind, 'kind', 'Not an offline reader file');
    }
  }

  Future<ColdigomDownloadResult> call({
    required Set<String> kindIds,
    Set<String>? selection,
    MaterialKindTaxonomy? taxonomy,
    CancelToken? cancelToken,
    void Function(ColdigomDownloadProgress)? onProgress,
  }) async {
    final targets = coldigomDownloadTargetsFrom(
      _catalog.findAllSync(),
      kindIds: kindIds,
      selection: selection,
      taxonomy: taxonomy,
    );
    final present = await _collectPresent(targets);

    final pending = <ColdigomDownloadTarget>[];
    var skipped = 0;
    for (final target in targets) {
      if (present.contains(target.localId)) {
        skipped++;
      } else {
        pending.add(target);
      }
    }

    final totalInKind = <String, int>{};
    for (final t in targets) {
      totalInKind.update(t.kindId, (v) => v + 1, ifAbsent: () => 1);
    }
    final doneInKind = <String, int>{};
    for (final t in targets) {
      if (present.contains(t.localId)) {
        doneInKind.update(t.kindId, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    var done = 0;
    var bytes = 0;
    var doneTotal = skipped;
    var stopped = false;
    var nextIndex = 0;
    final failed = <ColdigomDownloadFailure>[];

    // Uma emissão antes dos workers, com os totais já conhecidos
    // (`skipped`/`targets.length`) — sem isso uma chamada onde tudo já está
    // presente (`pending` vazio) nunca reporta nada, e a UI fica sem saber
    // que terminou.
    onProgress?.call(
      ColdigomDownloadProgress(
        kindId: '',
        doneInKind: 0,
        totalInKind: 0,
        doneTotal: doneTotal,
        total: targets.length,
        currentTitle: '',
      ),
    );

    Future<void> worker() async {
      while (!stopped) {
        if (cancelToken?.isCancelled ?? false) {
          stopped = true;
          break;
        }
        if (nextIndex >= pending.length) break;
        final target = pending[nextIndex++];
        try {
          // `bytes += await _download(...)` leria `bytes` antes do
          // `await` suspender — com workers concorrentes, dois deles
          // liam o mesmo valor velho e um incremento se perdia. Separar
          // a leitura do `await` garante que a soma é feita depois dele.
          final downloaded = await _download((
            kind: target.kind,
            id: target.localId,
            key: target.r2Key,
          ), cancelToken);
          bytes += downloaded;
          done++;
        } on InsufficientDiskSpaceException catch (error) {
          failed.add(
            ColdigomDownloadFailure(
              materialId: target.materialId,
              cause: error,
            ),
          );
          stopped = true;
          break;
        } on Object catch (error) {
          if (cancelToken?.isCancelled ?? false) {
            stopped = true;
            break;
          }
          debugPrint('[offline] coldigom ${target.materialId} falhou: $error');
          failed.add(
            ColdigomDownloadFailure(
              materialId: target.materialId,
              cause: error,
            ),
          );
        }
        doneTotal++;
        doneInKind.update(target.kindId, (v) => v + 1, ifAbsent: () => 1);
        onProgress?.call(
          ColdigomDownloadProgress(
            kindId: target.kindId,
            doneInKind: doneInKind[target.kindId] ?? 0,
            totalInKind: totalInKind[target.kindId] ?? 0,
            doneTotal: doneTotal,
            total: targets.length,
            currentTitle: target.title,
          ),
        );
      }
    }

    if (pending.isNotEmpty) {
      final workers = min(_concurrency, pending.length);
      await Future.wait(List.generate(workers, (_) => worker()));
    }

    if (!stopped && cancelToken?.isCancelled != true) {
      await _restoreLyrics?.call({
        for (final target in targets) target.praiseId,
      });
    }

    return ColdigomDownloadResult(
      done: done,
      skipped: skipped,
      failed: failed,
      bytes: bytes,
      cancelled: stopped,
    );
  }

  /// `localId`s já presentes, por tipo. PDFs no índice mas só em LRU são
  /// promovidos a persistentes aqui — sem novo download.
  Future<Set<String>> _collectPresent(
    List<ColdigomDownloadTarget> targets,
  ) async {
    final present = <String>{};

    final pdfIds = {
      for (final t in targets)
        if (t.kind == MaterialKind.pdf) t.localId,
    };
    if (pdfIds.isNotEmpty) {
      final valid = await _pdfRepository.lookupBatch(pdfIds);
      present.addAll(valid);
      final lru = {
        for (final entry in await _pdfRepository.listAll())
          if (!entry.isPersistent && valid.contains(entry.pdfId)) entry.pdfId,
      };
      if (lru.isNotEmpty) await _pdfLocal.markPersistent(lru);
    }

    final audioIds = {
      for (final t in targets)
        if (t.kind == MaterialKind.audio) t.localId,
    };
    if (audioIds.isNotEmpty) {
      present.addAll(await _audioRepository.lookupBatch(audioIds));
    }

    final scoreFiles = _scoreFiles;
    final scoreIsLocal =
        scoreFiles != null && targets.any((t) => t.kind == MaterialKind.score)
        ? await scoreFiles.localPresence()
        : null;
    final figurePresence = <String, Future<bool>>{};
    for (final t in targets) {
      if (t.kind == MaterialKind.chord && _chordLocal.read(t.r2Key) != null) {
        present.add(t.localId);
      }
      if (t.kind == MaterialKind.gesture) {
        final content = _gestureLocal.read(t.r2Key)?.content;
        if (content == '' || await _gestureAvailable(content, figurePresence)) {
          present.add(t.localId);
        }
      }
      if (t.kind == MaterialKind.score &&
          scoreIsLocal != null &&
          scoreIsLocal(t.r2Key)) {
        present.add(t.localId);
      }
    }
    return present;
  }

  Future<bool> _gestureAvailable(
    String? content, [
    Map<String, Future<bool>>? figurePresence,
  ]) async {
    if (content == null || content.isEmpty) return false;
    final keys = await _cachedFigureKeysFor(content);
    if (keys == null) return false;
    final present = await Future.wait(
      keys.map(
        (key) =>
            figurePresence?.putIfAbsent(key, () => _figures.hasLocal(key)) ??
            _figures.hasLocal(key),
      ),
    );
    return present.every((value) => value);
  }

  /// Bytes gravados para [material]; lança para o worker classificar.
  Future<int> _download(
    OfflineReaderMaterial material,
    CancelToken? cancelToken,
  ) async {
    final (:kind, :id, :key) = material;
    switch (kind) {
      case MaterialKind.pdf:
        // `FetchColdigomPdf` (produção: `FetchAndStorePdf`) já tenta até
        // `OfflineConfig.maxRetryAttempts` por conta própria — embrulhar em
        // `_withRetry` aqui multiplicaria as tentativas (até 9× de 120s por
        // PDF morto, como o comentário de `RetryInterceptor.disableKey`
        // adverte). Uma falha aqui já veio depois do retry interno dele.
        await _fetchPdf(id, key, cancelToken: cancelToken);
        // `FetchColdigomPdf` (void) não devolve o tamanho real — o PDF já
        // fica contabilizado no próprio `OfflinePdfRepository`/índice; o
        // `bytes` deste resultado só soma o que só esta chamada sabe medir
        // (áudio/cifra/gestos), não a estimativa de O13. Ver doc de
        // [ColdigomDownloadResult.bytes].
        return 0;
      case MaterialKind.audio:
        // `AudioBytesDatasource` desliga o `RetryInterceptor` de propósito
        // (ver seu doc) para retentar aqui, com o mesmo backoff do PDF —
        // é o único tipo sem retry em outra camada.
        final bytes = await _withRetry(
          () => _audioBytes.fetch(key, cancelToken: cancelToken),
        );
        await _audioRepository.upsert(audioId: id, r2Key: key, bytes: bytes);
        return bytes.length;
      case MaterialKind.chord:
        // `ChordContentDatasource` usa `coldigomDioProvider`, que já tem
        // `RetryInterceptor` — uma retentativa aqui seria inerte (o erro que
        // chega é `ChordFetchFailedException`, não `DioException`) e a
        // camada certa já cobre rede transitória/5xx.
        final content = await _chordRemote.fetchContent(key);
        _chordLocal.write(key, content ?? '');
        return content?.length ?? 0;
      case MaterialKind.gesture:
        // Mesmo raciocínio do cifra: `RetryInterceptor` de `coldigomDioProvider`
        // já cobre a rede transitória.
        final content = await _gestureRemote.fetchContent(key);
        // Figuras antes do documento: se a fila parar (quota/cancelamento)
        // no meio do prefetch, o documento não fica marcado "presente" e a
        // próxima chamada refaz fetch + prefetch — sem isso um documento já
        // gravado seria pulado com figuras nunca baixadas (O12).
        if (content != null) {
          final keys = await _figureKeysFor(content);
          if (keys == null) {
            throw StateError('Gesture dictionary unavailable for $key');
          }
          await _figures.prefetch(keys);
          if (!await _gestureAvailable(content)) {
            throw StateError('Gesture figures not persisted for $key');
          }
        }
        _gestureLocal.write(key, content ?? '');
        return content?.length ?? 0;
      case MaterialKind.score:
        // `ScoreFileRepository` usa `coldigomDioProvider` (com
        // `RetryInterceptor`), como cifra e gestos. Só conta como baixada
        // quando o store confirma a persistência, inclusive na web sem quota.
        final scoreFiles = _scoreFiles;
        if (scoreFiles == null) {
          throw StateError('partitura sem repositório: $key');
        }
        final bytes = await scoreFiles.fetch(key, cancelToken: cancelToken);
        if (bytes == null || !await scoreFiles.hasLocal(key)) {
          throw ScoreFetchFailedException(
            key,
            bytes == null ? 'arquivo não encontrado' : 'persistência falhou',
          );
        }
        return bytes.length;
      case MaterialKind.youtube:
      case MaterialKind.lyrics:
      case MaterialKind.unknown:
        // `coldigomDownloadTargetsFrom` nunca emite estes tipos.
        throw StateError('tipo não baixável: $kind');
    }
  }

  /// Mesmo backoff de `FetchAndStorePdf._fetchBytesWithRetry`; só
  /// `DioException` retryável (rede/5xx) é repetida. Só o caso `audio` usa
  /// isto — PDF já retenta em `FetchAndStorePdf`, cifra/gestos no
  /// `RetryInterceptor` de `coldigomDioProvider` (ver [_download]).
  Future<T> _withRetry<T>(Future<T> Function() attempt) async {
    for (var n = 1; ; n++) {
      try {
        return await attempt();
      } on DioException catch (error) {
        if (!isRetryableDioException(error) ||
            n >= OfflineConfig.maxRetryAttempts) {
          rethrow;
        }
        await Future<void>.delayed(retryDelayForAttempt(n));
      }
    }
  }
}
