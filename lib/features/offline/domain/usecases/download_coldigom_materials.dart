import 'dart:math' show min;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../audio_player/data/datasources/audio_bytes_datasource.dart';
import '../../../chords/data/datasources/chord_content_datasource.dart';
import '../../../chords/data/datasources/chord_content_local_datasource.dart';
import '../../../coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import '../../../gestures/data/datasources/gesture_content_datasource.dart';
import '../../../gestures/data/datasources/gesture_content_local_datasource.dart';
import '../../../gestures/data/repositories/gesture_figure_repository.dart';
import '../../data/datasources/offline_pdf_local_datasource.dart';
import '../entities/coldigom_download_progress.dart';
import '../entities/coldigom_download_target.dart';
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
typedef GestureFigureKeysResolver = Future<Set<String>> Function(
  String gestureJson,
);

/// Download dos materiais Coldigom dos [kindIds] escolhidos (spec §5.2, O12).
///
/// Idempotente e retomável por construção: enumera do catálogo local, salta
/// o que já está no índice/cache e pode ser parado e chamado de novo sem
/// checkpoint. Cada tipo persiste onde já persistia (C1/O7): PDF no
/// `OfflinePdfIndex` (LRU presente é só promovido), áudio no índice novo,
/// cifra e gestos nos caches Isar (404 vira marcador negativo e conta como
/// feito — o sheet já sabe que «não existe»).
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
  final int _concurrency;

  Future<ColdigomDownloadResult> call({
    required Set<String> kindIds,
    CancelToken? cancelToken,
    void Function(ColdigomDownloadProgress)? onProgress,
  }) async {
    final targets = coldigomDownloadTargetsFrom(
      _catalog.findAllSync(),
      kindIds: kindIds,
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
          final downloaded = await _download(target, cancelToken);
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

    for (final t in targets) {
      if (t.kind == MaterialKind.chord && _chordLocal.read(t.r2Key) != null) {
        present.add(t.localId);
      }
      if (t.kind == MaterialKind.gesture &&
          _gestureLocal.read(t.r2Key) != null) {
        present.add(t.localId);
      }
    }
    return present;
  }

  /// Bytes gravados para [target]; lança para o worker classificar.
  Future<int> _download(
    ColdigomDownloadTarget target,
    CancelToken? cancelToken,
  ) async {
    switch (target.kind) {
      case MaterialKind.pdf:
        // `FetchColdigomPdf` (produção: `FetchAndStorePdf`) já tenta até
        // `OfflineConfig.maxRetryAttempts` por conta própria — embrulhar em
        // `_withRetry` aqui multiplicaria as tentativas (até 9× de 120s por
        // PDF morto, como o comentário de `RetryInterceptor.disableKey`
        // adverte). Uma falha aqui já veio depois do retry interno dele.
        await _fetchPdf(target.localId, target.r2Key, cancelToken: cancelToken);
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
          () => _audioBytes.fetch(target.r2Key, cancelToken: cancelToken),
        );
        await _audioRepository.upsert(
          audioId: target.localId,
          r2Key: target.r2Key,
          bytes: bytes,
        );
        return bytes.length;
      case MaterialKind.chord:
        // `ChordContentDatasource` usa `coldigomDioProvider`, que já tem
        // `RetryInterceptor` — uma retentativa aqui seria inerte (o erro que
        // chega é `ChordFetchFailedException`, não `DioException`) e a
        // camada certa já cobre rede transitória/5xx.
        final content = await _chordRemote.fetchContent(target.r2Key);
        _chordLocal.write(target.r2Key, content ?? '');
        return content?.length ?? 0;
      case MaterialKind.gesture:
        // Mesmo raciocínio do cifra: `RetryInterceptor` de `coldigomDioProvider`
        // já cobre a rede transitória.
        final content = await _gestureRemote.fetchContent(target.r2Key);
        // Figuras antes do documento: se a fila parar (quota/cancelamento)
        // no meio do prefetch, o documento não fica marcado "presente" e a
        // próxima chamada refaz fetch + prefetch — sem isso um documento já
        // gravado seria pulado com figuras nunca baixadas (O12).
        if (content != null) {
          await _figures.prefetch(await _figureKeysFor(content));
        }
        _gestureLocal.write(target.r2Key, content ?? '');
        return content?.length ?? 0;
      case MaterialKind.youtube:
      case MaterialKind.lyrics:
      case MaterialKind.unknown:
        // `coldigomDownloadTargetsFrom` nunca emite estes tipos.
        throw StateError('tipo não baixável: ${target.rawType}');
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
