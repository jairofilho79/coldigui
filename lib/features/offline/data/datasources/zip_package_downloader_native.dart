import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/offline_config.dart';
import '../../../../core/network/retry_interceptor.dart';
import '../../domain/exceptions/offline_bulk_exceptions.dart';
import '../../domain/utils/download_retry.dart';
import '../../domain/ports/pdf_storage_port.dart';

/// Baixa pacotes ZIP para diretório transitório sob `plpcg_pdfs/_bulk_zips/`.
class ZipPackageDownloader {
  ZipPackageDownloader(this._dio, this._store, {Duration? stallTimeout})
    : _stallTimeout = stallTimeout ?? OfflineConfig.zipDownloadStallTimeout;

  final Dio _dio;
  final PdfStoragePort _store;

  /// Watchdog inter-chunk (injetável nos testes) — `Duration.zero` desliga.
  final Duration _stallTimeout;

  /// Assinatura de um arquivo ZIP (local file header) — `PK\x03\x04`.
  static const List<int> _zipSignature = [0x50, 0x4B, 0x03, 0x04];

  /// Baixa [url] (ex.: `/packages/Partitura-1.zip`) e retorna path absoluto local.
  ///
  /// Quando [expectedSize] é informado, reutiliza cache apenas se o tamanho
  /// no disco coincidir com o manifest **e** o arquivo começar com a assinatura
  /// ZIP — um ZIP corrompido em cache é apagado e baixado de novo. Retentativas
  /// preservam `.tmp` parcial e retomam via HTTP Range quando o servidor
  /// suporta.
  ///
  /// [activeCheckpointName] é o nome do ZIP da part apontada pelo checkpoint em
  /// curso: o `.tmp` dele (e o de [filename]) sobrevive à limpeza de órfãos
  /// feita no início de cada download.
  Future<String> download({
    required String url,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
    String? activeCheckpointName,
  }) async {
    final zipDir = await _zipDirectory();
    final target = File('${zipDir.path}/$filename');
    final tmp = File('${target.path}.tmp');

    await cleanOrphanedTempFiles(keep: {filename, ?activeCheckpointName});

    if (await target.exists()) {
      if (await _isUsableCachedZip(target, expectedSize)) {
        return target.path;
      }
      await target.delete();
    }

    final absoluteUrl = url.startsWith('http')
        ? url
        : '${AppConfig.apiBaseUrl}$url';

    Object? lastError;
    for (
      var attempt = 1;
      attempt <= OfflineConfig.maxRetryAttempts;
      attempt++
    ) {
      try {
        return await _downloadOnce(
          absoluteUrl: absoluteUrl,
          target: target,
          tmp: tmp,
          filename: filename,
          expectedSize: expectedSize,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
        );
      } on ZipDownloadCancelledException {
        // Cancelamento do usuário não é falha — nunca retenta.
        rethrow;
      } on ZipDownloadStalledException catch (e) {
        lastError = e;
        if (attempt >= OfflineConfig.maxRetryAttempts) rethrow;
        debugPrint(
          '[offline] stall no download de $filename '
          '(tentativa $attempt/${OfflineConfig.maxRetryAttempts})',
        );
        await Future<void>.delayed(retryDelayForAttempt(attempt));
      } on DioException catch (e) {
        lastError = e;
        if (!isRetryableDioException(e) ||
            attempt >= OfflineConfig.maxRetryAttempts) {
          rethrow;
        }
        await Future<void>.delayed(retryDelayForAttempt(attempt));
      } on ZipDownloadSizeMismatchException catch (e) {
        lastError = e;
        if (attempt >= OfflineConfig.maxRetryAttempts) rethrow;
        await Future<void>.delayed(retryDelayForAttempt(attempt));
      } on Object catch (e) {
        lastError = e;
        rethrow;
      }
    }

    throw lastError ?? StateError('download falhou sem erro capturado');
  }

  /// Lê bytes do ZIP baixado (para extração web-safe).
  Future<Uint8List> readZipBytes(String zipPath) => File(zipPath).readAsBytes();

  /// Não usado no nativo — bulk web baixa PDFs individualmente.
  Future<Uint8List> fetchPdfBytes(String pdfId, {CancelToken? cancelToken}) {
    throw UnsupportedError('fetchPdfBytes é exclusivo da web (Solução C)');
  }

  Future<String> _downloadOnce({
    required String absoluteUrl,
    required File target,
    required File tmp,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final guard = _ZipDownloadGuard(cancelToken, _stallTimeout);
    try {
      return await _runAttempt(
        absoluteUrl: absoluteUrl,
        target: target,
        tmp: tmp,
        filename: filename,
        expectedSize: expectedSize,
        guard: guard,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      final translated = guard.translate(e);
      // Erro não relacionado a cancelamento: `rethrow` preserva o stack trace.
      if (identical(translated, e)) rethrow;
      throw translated;
    } finally {
      guard.dispose();
    }
  }

  Future<String> _runAttempt({
    required String absoluteUrl,
    required File target,
    required File tmp,
    required String filename,
    required _ZipDownloadGuard guard,
    int? expectedSize,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final cancelToken = guard.token;
    void progress(int received, int total) {
      guard.ping();
      onReceiveProgress?.call(received, total);
    }

    guard.start();

    final partialSize = await _partialTempSize(tmp);
    final canResume =
        partialSize > 0 && expectedSize != null && partialSize < expectedSize;

    if (canResume) {
      final supportsRange = await _serverSupportsRange(
        absoluteUrl,
        cancelToken: cancelToken,
      );
      if (supportsRange) {
        await _appendRangeDownload(
          absoluteUrl: absoluteUrl,
          tmp: tmp,
          partialSize: partialSize,
          cancelToken: cancelToken,
          onReceiveProgress: progress,
        );
      } else {
        await tmp.delete();
        await _downloadFull(
          absoluteUrl,
          tmp,
          cancelToken,
          onReceiveProgress: progress,
        );
      }
    } else {
      if (partialSize > 0) {
        await tmp.delete();
      }
      await _downloadFull(
        absoluteUrl,
        tmp,
        cancelToken,
        onReceiveProgress: progress,
      );
    }

    guard.dispose();
    await _validateTempSize(tmp, expectedSize, filename: filename);
    await tmp.rename(target.path);
    return target.path;
  }

  /// Cache só vale com tamanho do manifest **e** assinatura ZIP (spec C.2).
  Future<bool> _isUsableCachedZip(File target, int? expectedSize) async {
    if (expectedSize != null) {
      final stat = await FileStat.stat(target.path);
      if (stat.size != expectedSize) return false;
    }
    return _hasZipSignature(target);
  }

  Future<bool> _hasZipSignature(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final header = await raf.read(_zipSignature.length);
      if (header.length != _zipSignature.length) return false;
      for (var i = 0; i < _zipSignature.length; i++) {
        if (header[i] != _zipSignature[i]) return false;
      }
      return true;
    } on FileSystemException catch (e) {
      debugPrint('[offline] falha ao ler assinatura de ${file.path}: $e');
      return false;
    } finally {
      await raf?.close();
    }
  }

  Future<int> _partialTempSize(File tmp) async {
    if (!await tmp.exists()) return 0;
    return tmp.length();
  }

  Future<bool> _serverSupportsRange(
    String url, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.head(url, cancelToken: cancelToken);
      final acceptRanges = response.headers.value('accept-ranges');
      return acceptRanges != null && acceptRanges.toLowerCase() == 'bytes';
    } on DioException catch (e) {
      // Cancelamento (usuário ou watchdog) não pode virar "servidor sem Range".
      if (e.type == DioExceptionType.cancel) rethrow;
      return false;
    }
  }

  Future<void> _downloadFull(
    String url,
    File tmp,
    CancelToken? cancelToken, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    await _dio.download(
      url,
      tmp.path,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      options: _downloadOptions(),
      // O `.tmp` parcial é o insumo da retomada por Range na próxima
      // tentativa: apagá-lo no stall zeraria o progresso (spec D.3).
      deleteOnError: false,
    );
  }

  Options _downloadOptions({Map<String, dynamic>? headers}) {
    return Options(
      receiveTimeout: OfflineConfig.zipDownloadReceiveTimeout,
      sendTimeout: OfflineConfig.zipDownloadSendTimeout,
      headers: headers,
      // `download` já retenta 3× com backoff próprio.
      extra: const {RetryInterceptor.disableKey: true},
    );
  }

  Future<void> _appendRangeDownload({
    required String absoluteUrl,
    required File tmp,
    required int partialSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final partFile = File('${tmp.path}.part');
    try {
      final response = await _dio.download(
        absoluteUrl,
        partFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        options: _downloadOptions(headers: {'Range': 'bytes=$partialSize-'}),
        // O `.part` é apagado no `finally` de qualquer jeito; o que não pode
        // sumir por erro é o `.tmp` acumulado, e o dio não distingue os dois.
        deleteOnError: false,
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode == 206) {
        final sink = tmp.openWrite(mode: FileMode.append);
        try {
          await sink.addStream(partFile.openRead());
        } finally {
          await sink.close();
        }
      } else if (statusCode == 200) {
        await tmp.delete();
        await partFile.rename(tmp.path);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Unexpected status $statusCode for range download',
        );
      }
    } finally {
      if (await partFile.exists()) {
        await partFile.delete();
      }
    }
  }

  Future<void> _validateTempSize(
    File tmp,
    int? expectedSize, {
    required String filename,
  }) async {
    if (expectedSize == null) return;

    final size = await tmp.length();
    if (size != expectedSize) {
      await tmp.delete();
      throw ZipDownloadSizeMismatchException(
        expected: expectedSize,
        actual: size,
        filename: filename,
      );
    }
  }

  /// Remove `.tmp` órfãos de downloads interrompidos (backlog #13).
  ///
  /// [keep] traz nomes de ZIP (ex.: `Partitura-1.zip`) cujo parcial deve
  /// sobreviver — tipicamente o download em curso e a part do checkpoint
  /// ativo. Sem eles, a limpeza apagaria justamente o parcial retomável.
  Future<void> cleanOrphanedTempFiles({Set<String> keep = const {}}) async {
    final zipDir = await _zipDirectory();
    if (!await zipDir.exists()) return;

    final protected = {for (final name in keep) _tempNameFor(name)};

    await for (final entity in zipDir.list()) {
      if (entity is! File || !entity.path.endsWith('.tmp')) continue;
      if (protected.contains(entity.uri.pathSegments.last)) continue;
      try {
        await entity.delete();
      } on FileSystemException {
        // Arquivo pode ter sido removido concorrentemente.
      }
    }
  }

  static String _tempNameFor(String zipName) =>
      zipName.endsWith('.tmp') ? zipName : '$zipName.tmp';

  /// Remove ZIP após extração bem-sucedida.
  Future<void> deleteZip(String zipPath) async {
    final file = File(zipPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _zipDirectory() async {
    final rootPath = await _store.rootPath;
    final zipDir = Directory('$rootPath/${OfflineConfig.zipTempSubdir}');
    if (!await zipDir.exists()) {
      await zipDir.create(recursive: true);
    }
    return zipDir;
  }
}

/// Token interno de uma tentativa + watchdog inter-chunk (spec C.2).
///
/// Os requests usam [token] (não o do usuário) para que o watchdog possa
/// abortar só a tentativa. Um cancelamento do usuário é espelhado no token
/// interno, e [translate] devolve a exceção certa para cada origem.
class _ZipDownloadGuard {
  _ZipDownloadGuard(this._userToken, this._stallTimeout) {
    final userToken = _userToken;
    if (userToken == null) return;
    if (userToken.isCancelled) {
      token.cancel(userToken.cancelError?.error ?? 'cancelled by user');
      return;
    }
    userToken.whenCancel.then((error) {
      if (_disposed || token.isCancelled) return;
      token.cancel(error.error ?? 'cancelled by user');
    });
  }

  final CancelToken? _userToken;
  final Duration _stallTimeout;

  final CancelToken token = CancelToken();

  Timer? _timer;
  bool _stalled = false;
  bool _disposed = false;

  void start() => _rearm();

  /// Chegou byte: reinicia a contagem do watchdog.
  void ping() => _rearm();

  void _rearm() {
    if (_disposed || _stalled) return;
    _timer?.cancel();
    if (_stallTimeout <= Duration.zero) return;
    _timer = Timer(_stallTimeout, () {
      _stalled = true;
      if (!token.isCancelled) token.cancel('stall');
    });
  }

  /// Classifica um cancelamento: usuário (fatal) vs. watchdog (retryável).
  Object translate(DioException e) {
    if (e.type != DioExceptionType.cancel) return e;
    if (_userToken?.isCancelled == true) {
      return const ZipDownloadCancelledException();
    }
    if (_stalled) return ZipDownloadStalledException(_stallTimeout);
    return const ZipDownloadCancelledException();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
