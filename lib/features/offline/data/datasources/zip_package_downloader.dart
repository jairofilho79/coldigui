import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/offline_config.dart';
import '../../domain/exceptions/offline_bulk_exceptions.dart';
import '../../domain/utils/download_retry.dart';
import '../../domain/ports/pdf_storage_port.dart';

/// Baixa pacotes ZIP para diretório transitório sob `plpcg_pdfs/_bulk_zips/`.
class ZipPackageDownloader {
  ZipPackageDownloader(this._dio, this._store);

  final Dio _dio;
  final PdfStoragePort _store;

  /// Baixa [url] (ex.: `/packages/Partitura-1.zip`) e retorna path absoluto local.
  ///
  /// Quando [expectedSize] é informado, reutiliza cache apenas se o tamanho
  /// no disco coincidir com o manifest. Retentativas preservam `.tmp` parcial
  /// e retomam via HTTP Range quando o servidor suporta.
  Future<String> download({
    required String url,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final zipDir = await _zipDirectory();
    final target = File('${zipDir.path}/$filename');
    final tmp = File('${target.path}.tmp');

    if (await target.exists()) {
      if (expectedSize == null) {
        return target.path;
      }
      final stat = await FileStat.stat(target.path);
      if (stat.size == expectedSize) {
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

  Future<String> _downloadOnce({
    required String absoluteUrl,
    required File target,
    required File tmp,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
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
          onReceiveProgress: onReceiveProgress,
        );
      } else {
        await tmp.delete();
        await _downloadFull(
          absoluteUrl,
          tmp,
          cancelToken,
          onReceiveProgress: onReceiveProgress,
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
        onReceiveProgress: onReceiveProgress,
      );
    }

    await _validateTempSize(tmp, expectedSize, filename: filename);
    await tmp.rename(target.path);
    return target.path;
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
    } on DioException {
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
    );
  }

  Options _downloadOptions({Map<String, dynamic>? headers}) {
    return Options(
      receiveTimeout: OfflineConfig.zipDownloadReceiveTimeout,
      sendTimeout: OfflineConfig.zipDownloadSendTimeout,
      headers: headers,
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

  /// Remove arquivos `.tmp` órfãos de downloads interrompidos (backlog #13).
  Future<void> cleanOrphanedTempFiles() async {
    final zipDir = await _zipDirectory();
    if (!await zipDir.exists()) return;

    await for (final entity in zipDir.list()) {
      if (entity is File && entity.path.endsWith('.tmp')) {
        try {
          await entity.delete();
        } on FileSystemException {
          // Arquivo pode ter sido removido concorrentemente.
        }
      }
    }
  }

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
