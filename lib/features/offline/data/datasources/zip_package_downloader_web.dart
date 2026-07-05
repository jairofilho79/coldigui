import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/offline_config.dart';
import '../../domain/exceptions/offline_bulk_exceptions.dart';
import '../../domain/utils/download_retry.dart';
import '../../domain/ports/pdf_storage_port.dart';

/// Baixa pacotes ZIP em memória (web — sem `dart:io`).
class ZipPackageDownloader {
  ZipPackageDownloader(this._dio, this._store);

  final Dio _dio;
  final PdfStoragePort _store;

  final Map<String, Uint8List> _zipCache = {};

  /// Baixa [url] e retorna chave lógica do ZIP em cache.
  Future<String> download({
    required String url,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final zipKey = await _zipKey(filename);

    final cached = _zipCache[zipKey];
    if (cached != null) {
      if (expectedSize == null || cached.length == expectedSize) {
        return zipKey;
      }
      _zipCache.remove(zipKey);
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
          zipKey: zipKey,
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

  /// Lê bytes do ZIP em cache (para extração via `ZipDecoder().decodeBytes`).
  Future<Uint8List> readZipBytes(String zipPath) async {
    final bytes = _zipCache[zipPath];
    if (bytes == null) {
      throw StateError('ZIP não encontrado em cache: $zipPath');
    }
    return bytes;
  }

  Future<String> _downloadOnce({
    required String absoluteUrl,
    required String zipKey,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final response = await _dio.get<List<int>>(
      absoluteUrl,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: OfflineConfig.zipDownloadReceiveTimeout,
        sendTimeout: OfflineConfig.zipDownloadSendTimeout,
      ),
    );

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Resposta vazia ao baixar $filename',
      );
    }

    final bytes = Uint8List.fromList(data);
    if (expectedSize != null && bytes.length != expectedSize) {
      throw ZipDownloadSizeMismatchException(
        expected: expectedSize,
        actual: bytes.length,
        filename: filename,
      );
    }

    _zipCache[zipKey] = bytes;
    return zipKey;
  }

  /// No-op na web — não há arquivos `.tmp` em disco.
  Future<void> cleanOrphanedTempFiles() async {}

  /// Remove ZIP do cache após extração bem-sucedida.
  Future<void> deleteZip(String zipPath) async {
    _zipCache.remove(zipPath);
  }

  Future<String> _zipKey(String filename) async {
    final rootPath = await _store.rootPath;
    return '$rootPath/${OfflineConfig.zipTempSubdir}/$filename';
  }
}
